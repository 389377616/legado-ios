//
//  ZipBuilder.swift
//  Legado-iOS
//
//  纯 Swift ZIP 打包工具 - 用于 EPUB 生成
//  支持 STORE 和 DEFLATE 方法，1:1 对齐 Android epublib 输出
//

import Foundation
import Compression

/// ZIP 文件构建器 - 纯 Swift 实现，无需外部依赖
/// 对应 Android 端 EpubWriter 的 ZIP 打包功能
class ZipBuilder {
    
    // ZIP 文件格式常量
    private static let localFileHeaderSignature: UInt32 = 0x04034b50
    private static let centralDirectorySignature: UInt32 = 0x02014b50
    private static let endOfCentralDirectorySignature: UInt32 = 0x06054b50
    
    // 压缩方法
    private static let methodStore: UInt16 = 0
    private static let methodDeflate: UInt16 = 8
    
    // 通用标志位
    private static let flagUTF8: UInt16 = 0x0800  // Bit 11: UTF-8 filenames
    
    /// ZIP 条目
    private struct ZipEntry {
        let name: String        // 文件名（相对路径，使用 / 分隔符）
        let data: Data          // 文件数据
        let compressedData: Data // 压缩后数据（STORE 方式下与 data 相同）
        let method: UInt16      // 压缩方法
        let crc32: UInt32       // CRC32 校验值
        let lastModified: Date  // 最后修改时间
        let localHeaderOffset: UInt32 // 本地文件头偏移量
        
        var uncompressedSize: UInt32 { UInt32(data.count) }
        var compressedSize: UInt32 { UInt32(compressedData.count) }
    }
    
    // 条目列表
    private var entries: [ZipEntry] = []
    
    // 是否对非 mimetype 文件使用 DEFLATE
    private let useDeflate: Bool
    
    init(useDeflate: Bool = true) {
        self.useDeflate = useDeflate
    }
    
    // MARK: - 添加文件
    
    /// 添加文件到 ZIP（STORE 方式，不压缩）
    /// - Parameters:
    ///   - name: 文件路径（使用 / 分隔符）
    ///   - data: 文件数据
    ///   - lastModified: 最后修改时间
    func addFile(name: String, data: Data, lastModified: Date = Date()) {
        let crc = computeCRC32(data)
        let entry = ZipEntry(
            name: name,
            data: data,
            compressedData: data,
            method: ZipBuilder.methodStore,
            crc32: crc,
            lastModified: lastModified,
            localHeaderOffset: 0 // 稍后计算
        )
        entries.append(entry)
    }
    
    /// 添加文件到 ZIP（自动选择压缩方式）
    /// mimetype 文件强制 STORE，其他文件根据 useDeflate 配置
    /// - Parameters:
    ///   - name: 文件路径
    ///   - data: 文件数据
    ///   - lastModified: 最后修改时间
    func addFileAuto(name: String, data: Data, lastModified: Date = Date()) {
        // mimetype 必须不压缩（EPUB 规范要求）
        if name == "mimetype" {
            addFile(name: name, data: data, lastModified: lastModified)
            return
        }
        
        if useDeflate && data.count > 0 {
            // 尝试 DEFLATE 压缩
            if let deflated = deflateData(data) {
                let crc = computeCRC32(data)
                let entry = ZipEntry(
                    name: name,
                    data: data,
                    compressedData: deflated,
                    method: ZipBuilder.methodDeflate,
                    crc32: crc,
                    lastModified: lastModified,
                    localHeaderOffset: 0
                )
                entries.append(entry)
                return
            }
        }
        
        // fallback to STORE
        addFile(name: name, data: data, lastModified: lastModified)
    }
    
    /// 添加字符串内容到 ZIP
    func addFile(name: String, content: String, encoding: String.Encoding = .utf8, lastModified: Date = Date()) {
        if let data = content.data(using: encoding) {
            addFileAuto(name: name, data: data, lastModified: lastModified)
        }
    }
    
    /// 从目录添加所有文件
    /// - Parameters:
    ///   - directoryURL: 源目录
    ///   - basePath: ZIP 内基础路径（默认为空，即目录内容直接在 ZIP 根目录）
    func addDirectoryContents(directoryURL: URL, basePath: String = "") throws {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: directoryURL, includingPropertiesForKeys: nil) else {
            return
        }
        
        for case let fileURL as URL in enumerator {
            var isDir: ObjCBool = false
            fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDir)
            if isDir.boolValue { continue }
            
            let relativePath = fileURL.path.replacingOccurrences(of: directoryURL.path + "/", with: "")
            let zipPath = basePath.isEmpty ? relativePath : "\(basePath)/\(relativePath)"
            let data = try Data(contentsOf: fileURL)
            addFileAuto(name: zipPath, data: data)
        }
    }
    
    // MARK: - 构建 ZIP 数据
    
    /// 生成 ZIP 文件数据
    /// 规范要求 mimetype 必须排第一且不压缩
    func build() -> Data {
        var result = Data()
        
        // 确保 mimetype 排第一
        var sortedEntries = entries
        if let mimetypeIndex = sortedEntries.firstIndex(where: { $0.name == "mimetype" }) {
            let mimetypeEntry = sortedEntries.remove(at: mimetypeIndex)
            sortedEntries.insert(mimetypeEntry, at: 0)
        }
        
        // 计算偏移量并写入本地文件头 + 数据
        var currentOffset: UInt32 = 0
        for i in 0..<sortedEntries.count {
            let entry = sortedEntries[i]
            // 更新偏移量
            sortedEntries[i] = ZipEntry(
                name: entry.name,
                data: entry.data,
                compressedData: entry.compressedData,
                method: entry.method,
                crc32: entry.crc32,
                lastModified: entry.lastModified,
                localHeaderOffset: currentOffset
            )
            
            let localHeader = buildLocalFileHeader(entry: sortedEntries[i])
            result.append(localHeader)
            result.append(sortedEntries[i].compressedData)
            
            currentOffset = UInt32(result.count)
        }
        
        // 中央目录起始偏移
        let centralDirectoryOffset = currentOffset
        
        // 写入中央目录
        for entry in sortedEntries {
            let centralEntry = buildCentralDirectoryEntry(entry: entry)
            result.append(centralEntry)
        }
        
        let centralDirectorySize = UInt32(result.count) - centralDirectoryOffset
        
        // 写入结束中央目录记录
        let endRecord = buildEndOfCentralDirectory(
            entryCount: UInt16(sortedEntries.count),
            centralDirectorySize: centralDirectorySize,
            centralDirectoryOffset: centralDirectoryOffset
        )
        result.append(endRecord)
        
        return result
    }
    
    /// 构建 ZIP 并写入文件
    func write(to url: URL) throws {
        let data = build()
        try data.write(to: url)
    }
    
    // MARK: - ZIP 结构构建
    
    /// DOS 日期时间转换
    private func dosDateTime(from date: Date) -> (time: UInt16, date: UInt16) {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = components.second ?? 0
        let dosTime = UInt16((hour << 11) | (minute << 5) | (second / 2))
        
        let year = (components.year ?? 1980) - 1980
        let month = components.month ?? 1
        let day = components.day ?? 1
        let dosDate = UInt16((year << 9) | (month << 5) | day)
        
        return (dosTime, dosDate)
    }
    
    /// 本地文件头（Local File Header）
    private func buildLocalFileHeader(entry: ZipEntry) -> Data {
        var data = Data()
        let nameData = entry.name.data(using: .utf8) ?? Data()
        let (dosTime, dosDate) = dosDateTime(from: entry.lastModified)
        
        data.appendLittleEndian(ZipBuilder.localFileHeaderSignature)   // 4  本地文件头签名
        data.appendLittleEndian(UInt16(20))                            // 2  解压所需版本
        data.appendLittleEndian(ZipBuilder.flagUTF8)                   // 2  通用位标志
        data.appendLittleEndian(entry.method)                          // 2  压缩方法
        data.appendLittleEndian(dosTime)                               // 2  最后修改时间
        data.appendLittleEndian(dosDate)                               // 2  最后修改日期
        data.appendLittleEndian(entry.crc32)                           // 4  CRC-32
        data.appendLittleEndian(entry.compressedSize)                 // 4  压缩大小
        data.appendLittleEndian(entry.uncompressedSize)               // 4  未压缩大小
        data.appendLittleEndian(UInt16(nameData.count))               // 2  文件名长度
        data.appendLittleEndian(UInt16(0))                             // 2  额外字段长度
        data.append(nameData)                                          // 变长 文件名
        
        return data
    }
    
    /// 中央目录条目（Central Directory Entry）
    private func buildCentralDirectoryEntry(entry: ZipEntry) -> Data {
        var data = Data()
        let nameData = entry.name.data(using: .utf8) ?? Data()
        let (dosTime, dosDate) = dosDateTime(from: entry.lastModified)
        
        data.appendLittleEndian(ZipBuilder.centralDirectorySignature)  // 4  中央目录签名
        data.appendLittleEndian(UInt16(20))                            // 2  制作版本
        data.appendLittleEndian(UInt16(20))                            // 2  解压所需版本
        data.appendLittleEndian(ZipBuilder.flagUTF8)                   // 2  通用位标志
        data.appendLittleEndian(entry.method)                          // 2  压缩方法
        data.appendLittleEndian(dosTime)                               // 2  最后修改时间
        data.appendLittleEndian(dosDate)                               // 2  最后修改日期
        data.appendLittleEndian(entry.crc32)                           // 4  CRC-32
        data.appendLittleEndian(entry.compressedSize)                 // 4  压缩大小
        data.appendLittleEndian(entry.uncompressedSize)               // 4  未压缩大小
        data.appendLittleEndian(UInt16(nameData.count))               // 2  文件名长度
        data.appendLittleEndian(UInt16(0))                             // 2  额外字段长度
        data.appendLittleEndian(UInt16(0))                             // 2  文件注释长度
        data.appendLittleEndian(UInt16(0))                             // 2  磁盘号起点
        data.appendLittleEndian(UInt16(0))                             // 2  内部文件属性
        data.appendLittleEndian(UInt32(0))                             // 4  外部文件属性
        data.appendLittleEndian(entry.localHeaderOffset)               // 4  本地文件头偏移
        data.append(nameData)                                          // 变长 文件名
        
        return data
    }
    
    /// 结束中央目录记录（End of Central Directory Record）
    private func buildEndOfCentralDirectory(
        entryCount: UInt16,
        centralDirectorySize: UInt32,
        centralDirectoryOffset: UInt32
    ) -> Data {
        var data = Data()
        
        data.appendLittleEndian(ZipBuilder.endOfCentralDirectorySignature) // 4  签名
        data.appendLittleEndian(UInt16(0))                            // 2  当前磁盘号
        data.appendLittleEndian(UInt16(0))                            // 2  中央目录开始磁盘号
        data.appendLittleEndian(entryCount)                           // 2  本磁盘条目数
        data.appendLittleEndian(entryCount)                           // 2  总条目数
        data.appendLittleEndian(centralDirectorySize)                 // 4  中央目录大小
        data.appendLittleEndian(centralDirectoryOffset)               // 4  中央目录偏移
        data.appendLittleEndian(UInt16(0))                            // 2  注释长度
        
        return data
    }
    
    // MARK: - CRC32
    
    /// 计算 CRC32 校验值
    private func computeCRC32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        let table = crc32Table()
        
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ table[index]
        }
        return crc ^ 0xFFFFFFFF
    }
    
    /// CRC32 查找表
    private func crc32Table() -> [UInt32] {
        var table = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var crc = UInt32(i)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc >>= 1
                }
            }
            table[i] = crc
        }
        return table
    }
    
    // MARK: - DEFLATE 压缩
    
    /// 使用 Apple Compression 框架进行 DEFLATE 压缩
    private func deflateData(_ sourceData: Data) -> Data? {
        guard sourceData.count > 0 else { return nil }
        
        let sourceBufferSize = sourceData.count
        let destBufferSize = sourceBufferSize + sourceBufferSize / 2 + 64
        var destBuffer = [UInt8](repeating: 0, count: destBufferSize)
        
        let result: Int = sourceData.withUnsafeBytes { sourcePtr in
            guard let sourceAddress = sourcePtr.baseAddress else { return 0 }
            let sourcePtrBound = sourceAddress.assumingMemoryBound(to: UInt8.self)
            
            return destBuffer.withUnsafeMutableBufferPointer { destPtr in
                guard let destAddress = destPtr.baseAddress else { return 0 }
                return compression_encode_buffer(
                    destAddress,
                    destBufferSize,
                    sourcePtrBound,
                    sourceBufferSize,
                    nil,
                    COMPRESSION_DEFLATE
                )
            }
        }
        
        if result > 0 {
            return Data(destBuffer[0..<result])
        }
        return nil
    }
}

// MARK: - Data 扩展（小端写入）

private extension Data {
    mutating func appendLittleEndian(_ value: UInt16) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: MemoryLayout<UInt16>.size))
    }
    
    mutating func appendLittleEndian(_ value: UInt32) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: MemoryLayout<UInt32>.size))
    }
}
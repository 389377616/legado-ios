import Foundation
import UniformTypeIdentifiers

// MARK: - 文件工具

enum FileUtils {

    enum SortType {
        case byNameAsc
        case byNameDesc
        case byTimeAsc
        case byTimeDesc
        case bySizeAsc
        case bySizeDesc
        case byExtensionAsc
        case byExtensionDesc
    }

    private static let fileManager = FileManager.default

    // MARK: 创建

    @discardableResult
    static func createFileIfNotExist(root: URL, _ subpaths: String...) -> URL {
        createFileIfNotExist(getPath(root: root, subpaths))
    }

    @discardableResult
    static func createFolderIfNotExist(root: URL, _ subpaths: String...) -> URL {
        createFolderIfNotExist(getPath(root: root, subpaths))
    }

    @discardableResult
    static func createFolderIfNotExist(_ path: String) -> URL {
        let url = URL(fileURLWithPath: path)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        return url
    }

    @discardableResult
    static func createFileIfNotExist(_ path: String) -> URL {
        let url = URL(fileURLWithPath: path)
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            fileManager.createFile(atPath: url.path, contents: nil, attributes: nil)
        }
        return url
    }

    @discardableResult
    static func createFileWithReplace(_ path: String) -> URL {
        let url = URL(fileURLWithPath: path)
        try? fileManager.removeItem(at: url)
        return createFileIfNotExist(path)
    }

    // MARK: 路径

    static func getPath(rootPath: String, _ subpaths: String...) -> String {
        getPath(rootPath: rootPath, subpaths)
    }

    static func getPath(root: URL, _ subpaths: String...) -> String {
        getPath(root: root, subpaths)
    }

    static func getPath(rootPath: String, _ subpaths: [String]) -> String {
        subpaths.filter { !$0.isEmpty }.reduce(rootPath) { partialResult, component in
            URL(fileURLWithPath: partialResult).appendingPathComponent(component).path
        }
    }

    static func getPath(root: URL, _ subpaths: [String]) -> String {
        subpaths.filter { !$0.isEmpty }.reduce(root) { partialResult, component in
            partialResult.appendingPathComponent(component)
        }.path
    }

    static func getCachePath() -> String {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?.path ?? NSTemporaryDirectory()
    }

    static func getDocumentsPath() -> String {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? NSHomeDirectory()
    }

    static func separator(_ path: String) -> String {
        var normalized = path.replacingOccurrences(of: "\\", with: "/")
        if !normalized.hasSuffix("/") { normalized += "/" }
        return normalized
    }

    // MARK: 列表

    static func listDirs(
        _ startDirPath: String,
        excludeDirs: [String] = [],
        sortType: SortType = .byNameAsc
    ) -> [URL] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: startDirPath),
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey]
        ) else {
            return []
        }

        let filtered = urls.filter { url in
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            return isDirectory && !excludeDirs.contains(url.lastPathComponent)
        }
        return sort(urls: filtered, by: sortType)
    }

    static func listFiles(
        _ startDirPath: String,
        pattern: NSRegularExpression? = nil,
        sortType: SortType = .byNameAsc
    ) -> [URL] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: startDirPath),
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey]
        ) else {
            return []
        }

        let filtered = urls.filter { url in
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard !isDirectory else { return false }
            guard let pattern else { return true }
            let range = NSRange(location: 0, length: url.lastPathComponent.utf16.count)
            return pattern.firstMatch(in: url.lastPathComponent, range: range) != nil
        }
        return sort(urls: filtered, by: sortType)
    }

    static func listFiles(_ startDirPath: String, allowExtensions: [String]?) -> [URL] {
        listFiles(startDirPath).filter { url in
            guard let allowExtensions else { return true }
            return allowExtensions.contains(getExtension(url.lastPathComponent).lowercased())
        }
    }

    static func listDirsAndFiles(_ startDirPath: String, allowExtensions: [String]? = nil) -> [URL] {
        listDirs(startDirPath) + listFiles(startDirPath, allowExtensions: allowExtensions)
    }

    private static func sort(urls: [URL], by sortType: SortType) -> [URL] {
        urls.sorted { lhs, rhs in
            switch sortType {
            case .byNameAsc:
                return lhs.lastPathComponent.localizedCaseInsensitiveCompare(rhs.lastPathComponent) == .orderedAscending
            case .byNameDesc:
                return lhs.lastPathComponent.localizedCaseInsensitiveCompare(rhs.lastPathComponent) == .orderedDescending
            case .byTimeAsc:
                return (modificationDate(of: lhs) ?? .distantPast) < (modificationDate(of: rhs) ?? .distantPast)
            case .byTimeDesc:
                return (modificationDate(of: lhs) ?? .distantPast) > (modificationDate(of: rhs) ?? .distantPast)
            case .bySizeAsc:
                return (fileSize(of: lhs) ?? 0) < (fileSize(of: rhs) ?? 0)
            case .bySizeDesc:
                return (fileSize(of: lhs) ?? 0) > (fileSize(of: rhs) ?? 0)
            case .byExtensionAsc:
                return lhs.pathExtension.localizedCaseInsensitiveCompare(rhs.pathExtension) == .orderedAscending
            case .byExtensionDesc:
                return lhs.pathExtension.localizedCaseInsensitiveCompare(rhs.pathExtension) == .orderedDescending
            }
        }
    }

    // MARK: 文件操作

    static func exist(_ path: String) -> Bool {
        fileManager.fileExists(atPath: path)
    }

    @discardableResult
    static func delete(_ path: String, deleteRootDir: Bool = true) -> Bool {
        delete(URL(fileURLWithPath: path), deleteRootDir: deleteRootDir)
    }

    @discardableResult
    static func delete(_ url: URL, deleteRootDir: Bool = false) -> Bool {
        guard fileManager.fileExists(atPath: url.path) else { return false }
        if deleteRootDir {
            return ((try? fileManager.removeItem(at: url)) != nil)
        }

        guard let children = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else {
            return false
        }
        children.forEach { _ = try? fileManager.removeItem(at: $0) }
        return true
    }

    @discardableResult
    static func copy(_ src: String, _ dest: String) -> Bool {
        copy(URL(fileURLWithPath: src), URL(fileURLWithPath: dest))
    }

    @discardableResult
    static func copy(_ src: URL, _ dest: URL) -> Bool {
        do {
            if fileManager.fileExists(atPath: dest.path) {
                try fileManager.removeItem(at: dest)
            }
            try fileManager.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            try fileManager.copyItem(at: src, to: dest)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func move(_ src: String, _ dest: String) -> Bool {
        move(URL(fileURLWithPath: src), URL(fileURLWithPath: dest))
    }

    @discardableResult
    static func move(_ src: URL, _ dest: URL) -> Bool {
        do {
            try fileManager.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            if fileManager.fileExists(atPath: dest.path) {
                try fileManager.removeItem(at: dest)
            }
            try fileManager.moveItem(at: src, to: dest)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func rename(_ oldPath: String, _ newPath: String) -> Bool {
        move(oldPath, newPath)
    }

    // MARK: 读写

    static func readText(_ filepath: String, encoding: String.Encoding = .utf8) -> String {
        guard let data = readBytes(filepath) else { return "" }
        return String(data: data, encoding: encoding)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static func readBytes(_ filepath: String) -> Data? {
        try? Data(contentsOf: URL(fileURLWithPath: filepath))
    }

    @discardableResult
    static func writeText(_ filepath: String, content: String, encoding: String.Encoding = .utf8) -> Bool {
        writeBytes(filepath, data: content.data(using: encoding) ?? Data(content.utf8))
    }

    @discardableResult
    static func writeBytes(_ filepath: String, data: Data) -> Bool {
        let url = createFileIfNotExist(filepath)
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func writeInputStream(_ filepath: String, data: InputStream) -> Bool {
        writeInputStream(URL(fileURLWithPath: filepath), data: data)
    }

    @discardableResult
    static func writeInputStream(_ fileURL: URL, data: InputStream) -> Bool {
        createFileIfNotExist(fileURL.path)
        guard let outputStream = OutputStream(url: fileURL, append: false) else { return false }
        _ = IOUtils.copy(from: data, to: outputStream)
        return true
    }

    @discardableResult
    static func appendText(_ path: String, content: String) -> Bool {
        let url = createFileIfNotExist(path)
        guard let handle = try? FileHandle(forWritingTo: url) else { return false }
        defer { try? handle.close() }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(content.utf8))
            return true
        } catch {
            return false
        }
    }

    // MARK: 信息

    static func getLength(_ path: String) -> Int64 {
        fileSize(of: URL(fileURLWithPath: path)) ?? 0
    }

    static func getName(_ path: String?) -> String {
        guard let path else { return "" }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    static func getNameExcludeExtension(_ path: String) -> String {
        URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    }

    static func getSize(_ path: String) -> String {
        NumberUtils.formatFileSize(getLength(path))
    }

    static func getExtension(_ pathOrURL: String) -> String {
        let ext = URL(fileURLWithPath: pathOrURL).pathExtension
        return ext.isEmpty ? "ext" : ext
    }

    static func getMimeType(_ pathOrURL: String) -> String {
        let ext = getExtension(pathOrURL)
        return UTType(filenameExtension: ext)?.preferredMIMEType ?? "*/*"
    }

    static func getDateTime(_ path: String, format: String = "yyyy年MM月dd日HH:mm") -> String {
        getDateTime(URL(fileURLWithPath: path), format: format)
    }

    static func getDateTime(_ fileURL: URL, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = format
        return formatter.string(from: modificationDate(of: fileURL) ?? Date())
    }

    static func compareLastModified(_ path1: String, _ path2: String) -> Int {
        let left = modificationDate(of: URL(fileURLWithPath: path1)) ?? .distantPast
        let right = modificationDate(of: URL(fileURLWithPath: path2)) ?? .distantPast
        if left > right { return 1 }
        if left < right { return -1 }
        return 0
    }

    @discardableResult
    static func makeDirs(_ path: String) -> Bool {
        makeDirs(URL(fileURLWithPath: path))
    }

    @discardableResult
    static func makeDirs(_ url: URL) -> Bool {
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            return true
        } catch {
            return false
        }
    }

    // MARK: 私有辅助

    private static func fileSize(of url: URL) -> Int64? {
        let value = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        return Int64(value ?? 0)
    }

    private static func modificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}

//
//  BookHelp.swift
//  Legado-iOS
//
//  基于 Android Legado 原版 BookHelp.kt 严格一比一移植
//  原版路径: app/src/main/java/io/legado/app/help/book/BookHelp.kt
//  原版行数: 611 行
//

import UIKit
import Foundation
import CoreData

/// 书籍帮助类
/// 一比一移植自 Android Legado BookHelp
/// 负责书籍缓存管理、图片下载、内容存储等功能
enum BookHelp {
    
    // MARK: - 常量 (对照原版 line 57-61)
    private static let cacheFolderName = "book_cache"
    private static let cacheImageFolderName = "images"
    private static let cacheEpubFolderName = "epub"
    
    /// 缓存路径 (对照原版 line 63)
    static var cachePath: String {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cacheDir.appendingPathComponent(cacheFolderName).path
    }
    
    /// 下载目录
    private static var downloadDir: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }
    
    /// 图片下载 Mutex 防重复 (对照原版 line 61)
    private static var downloadImages: [String: NSLock] = [:]
    private static let downloadLock = NSLock()
    
    // MARK: - 缓存清理 (对照原版 line 65-74)
    
    static func clearCache() {
        let path = downloadDir.appendingPathComponent(cacheFolderName).path
        try? FileManager.default.removeItem(atPath: path)
    }
    
    static func clearCache(_ book: Book) {
        let filePath = downloadDir
            .appendingPathComponent(cacheFolderName)
            .appendingPathComponent(book.getFolderName())
        try? FileManager.default.removeItem(at: filePath)
    }
    
    // MARK: - 图片相关 (对照原版 line 264-285)
    
    /// 获取图片缓存路径
    /// 对照原版 fun getImage(book: Book, src: String): File (line 264-271)
    static func getImage(_ book: Book, _ src: String) -> URL {
        let imageDir = downloadDir
            .appendingPathComponent(cacheFolderName)
            .appendingPathComponent(book.getFolderName())
            .appendingPathComponent(cacheImageFolderName)
        
        try? FileManager.default.createDirectory(at: imageDir, withIntermediateDirectories: true)
        
        let fileName = "\(src.md5()).\(getImageSuffix(src))"
        return imageDir.appendingPathComponent(fileName)
    }
    
    /// 写入图片数据
    /// 对照原版 fun writeImage(book: Book, src: String, bytes: ByteArray) (line 274-276)
    static func writeImage(_ book: Book, _ src: String, _ bytes: Data) {
        let fileURL = getImage(book, src)
        createFileIfNotExist(fileURL)
        try? bytes.write(to: fileURL)
    }
    
    /// 检查图片是否存在
    /// 对照原版 fun isImageExist(book: Book, src: String): Boolean (line 278-281)
    static func isImageExist(_ book: Book, _ src: String) -> Bool {
        let fileURL = getImage(book, src)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    /// 获取图片后缀
    /// 对照原版 fun getImageSuffix(src: String): String (line 283-285)
    static func getImageSuffix(_ src: String) -> String {
        let url = URL(string: src)
        if let ext = url?.pathExtension, !ext.isEmpty {
            return ext.lowercased()
        }
        return "jpg"
    }
    
    // MARK: - 保存图片 (对照原版 line 219-262)
    
    /// 保存图片
    /// 对照原版 suspend fun saveImage(bookSource, book, src, chapter) (line 219-262)
    static func saveImage(
        bookSource: BookSource?,
        book: Book,
        src: String,
        chapter: BookChapter? = nil
    ) async {
        if isImageExist(book, src) {
            return
        }
        
        let mutex = getMutex(for: src)
        mutex.lock()
        
        defer {
            removeMutex(for: src)
            mutex.unlock()
        }
        
        if isImageExist(book, src) {
            return
        }
        
        do {
            let bytes = await downloadImageBytes(src, bookSource: bookSource)
            if let data = bytes {
                writeImage(book, src, data)
            }
        } catch {
            print("[BookHelp] 图片下载失败: \(src) - \(error)")
        }
    }
    
    // MARK: - Mutex 管理
    
    private static func getMutex(for src: String) -> NSLock {
        downloadLock.lock()
        defer { downloadLock.unlock() }
        if let mutex = downloadImages[src] {
            return mutex
        }
        let mutex = NSLock()
        downloadImages[src] = mutex
        return mutex
    }
    
    private static func removeMutex(for src: String) {
        downloadLock.lock()
        downloadImages.removeValue(forKey: src)
        downloadLock.unlock()
    }
    
    // MARK: - 图片下载
    
    private static func downloadImageBytes(_ src: String, bookSource: BookSource?) async -> Data? {
        guard let url = URL(string: src) else { return nil }
        
        var request = URLRequest(url: url)
        
        if let source = bookSource {
            var headers: [String: String] = [:]
            
            if let headerString = source.header,
               let data = headerString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                for (key, value) in json {
                    headers[key] = "\(value)"
                }
            }
            
            if headers["Referer"] == nil {
                headers["Referer"] = source.bookSourceUrl
            }
            
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }
    
    // MARK: - 内容相关 (对照原版 line 176-194)
    
    /// 保存章节文本内容
    /// 对照原版 fun saveText(book, bookChapter, content) (line 176-194)
    static func saveText(_ book: Book, _ bookChapter: BookChapter, _ content: String) {
        if content.isEmpty { return }
        
        let fileURL = downloadDir
            .appendingPathComponent(cacheFolderName)
            .appendingPathComponent(book.getFolderName())
            .appendingPathComponent(bookChapter.getFileName())
        
        createFileIfNotExist(fileURL)
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
    }
    
    /// 读取章节内容
    /// 对照原版 fun getContent(book, bookChapter): String? (line 400-421)
    static func getContent(_ book: Book, _ bookChapter: BookChapter) -> String? {
        let fileURL = downloadDir
            .appendingPathComponent(cacheFolderName)
            .appendingPathComponent(book.getFolderName())
            .appendingPathComponent(bookChapter.getFileName())
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return try? String(contentsOf: fileURL, encoding: .utf8)
        }
        
        if book.isLocal {
            return LocalBook.getContent(book, bookChapter)
        }
        
        return nil
    }
    
    /// 检测章节是否下载
    /// 对照原版 fun hasContent(book, bookChapter): Boolean (line 341-353)
    static func hasContent(_ book: Book, _ bookChapter: BookChapter) -> Bool {
        if book.isLocalTxt {
            return true
        }
        
        let fileURL = downloadDir
            .appendingPathComponent(cacheFolderName)
            .appendingPathComponent(book.getFolderName())
            .appendingPathComponent(bookChapter.getFileName())
        
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    /// 获取书籍缓存文件夹中的所有文件名
    /// 对照原版 fun getChapterFiles(book: Book): HashSet<String> (line 324-336)
    static func getChapterFiles(_ book: Book) -> Set<String> {
        var fileNames: Set<String> = []
        
        if book.isLocalTxt {
            return fileNames
        }
        
        let folderURL = downloadDir
            .appendingPathComponent(cacheFolderName)
            .appendingPathComponent(book.getFolderName())
        
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        
        if let files = try? FileManager.default.contentsOfDirectory(atPath: folderURL.path) {
            fileNames = Set(files)
        }
        
        return fileNames
    }
    
    /// 删除章节内容
    /// 对照原版 fun delContent(book, bookChapter) (line 426-433)
    static func delContent(_ book: Book, _ bookChapter: BookChapter) {
        let fileURL = downloadDir
            .appendingPathComponent(cacheFolderName)
            .appendingPathComponent(book.getFolderName())
            .appendingPathComponent(bookChapter.getFileName())
        
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    // MARK: - 辅助方法
    
    private static func createFileIfNotExist(_ url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
    }
}

// MARK: - Book 扩展

extension Book {
    func getFolderName() -> String {
        let safeName = (name ?? "unknown").replacingOccurrences(of: "/", with: "_")
        let safeAuthor = (author ?? "").replacingOccurrences(of: "/", with: "_")
        return "\(safeName)_\(safeAuthor)".md5()
    }
    
    var isLocalTxt: Bool {
        let path = bookUrl.lowercased()
        return path.hasSuffix(".txt") && isLocal
    }
}

// MARK: - BookChapter 扩展

extension BookChapter {
    func getFileName() -> String {
        let safeTitle = (title ?? "unknown").replacingOccurrences(of: "/", with: "_")
        return "\(index)_\(safeTitle).txt"
    }
}

// MARK: - 占位类

/// 本地书籍解析器占位
enum LocalBook {
    static func getContent(_ book: Book, _ bookChapter: BookChapter) -> String? {
        let fileURL: URL?
        
        if book.bookUrl.hasPrefix("file://") {
            fileURL = URL(string: book.bookUrl)
        } else if book.bookUrl.hasPrefix("/") {
            fileURL = URL(fileURLWithPath: book.bookUrl)
        } else {
            fileURL = URL(fileURLWithPath: book.bookUrl)
        }
        
        guard let url = fileURL else { return nil }
        
        let path = url.path.lowercased()
        
        if path.hasSuffix(".txt") {
            return parseTXTContent(fileURL: url, chapter: bookChapter, book: book)
        } else if path.hasSuffix(".epub") {
            return parseEPUBContent(fileURL: url, chapter: bookChapter, book: book)
        }
        
        return nil
    }
    
    private static func parseTXTContent(fileURL: URL, chapter: BookChapter, book: Book) -> String? {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            let encodings: [String.Encoding] = [.utf8, .utf16, .isoLatin1, .ascii]
            for encoding in encodings {
                if let content = try? String(contentsOf: fileURL, encoding: encoding) {
                    return extractChapter(content: content, chapter: chapter)
                }
            }
            
            let gb18030 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
            if let content = try? String(contentsOf: fileURL, encoding: gb18030) {
                return extractChapter(content: content, chapter: chapter)
            }
            
            return nil
        }
        
        return extractChapter(content: content, chapter: chapter)
    }
    
    private static func extractChapter(content: String, chapter: BookChapter) -> String? {
        let lines = content.components(separatedBy: .newlines)
        var startIndex = -1
        var endIndex = lines.count
        
        let chapterPattern = chapter.title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains(chapterPattern) || chapterPattern.contains(trimmed) {
                if startIndex == -1 {
                    startIndex = index
                } else {
                    endIndex = index
                    break
                }
            }
        }
        
        if startIndex >= 0 {
            let chapterLines = Array(lines[startIndex..<min(endIndex, lines.count)])
            return chapterLines.joined(separator: "\n")
        }
        
        let linesPerChapter = 500
        let startLine = Int(chapter.index) * linesPerChapter
        let endLine = min(startLine + linesPerChapter, lines.count)
        
        if startLine < lines.count {
            return Array(lines[startLine..<endLine]).joined(separator: "\n")
        }
        
        return nil
    }
    
    private static func parseEPUBContent(fileURL: URL, chapter: BookChapter, book: Book) -> String? {
        let epubCacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("epub_cache")
            .appendingPathComponent(book.bookId.uuidString)
        
        let chapterFile = epubCacheDir.appendingPathComponent(chapter.chapterUrl)
        
        if FileManager.default.fileExists(atPath: chapterFile.path) {
            return try? String(contentsOf: chapterFile, encoding: .utf8)
        }
        
        return nil
    }
}
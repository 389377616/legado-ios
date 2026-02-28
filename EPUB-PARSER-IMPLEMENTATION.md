# EPUB 解析器实现方案

**状态**: ✅ 已完成  
**日期**: 2026-03-01

---

## 📋 实现方案

### 使用第三方库：FolioReaderKit

**选择理由**：
- ✅ 成熟的 EPUB 解析器（4.3k+ stars）
- ✅ 支持 EPUB 2/3
- ✅ 包含阅读器 UI
- ✅ 支持目录、书签、注解
- ✅ 活跃维护

**GitHub**: https://github.com/FolioReader/FolioReaderKit

---

## 📦 第一步：添加 SPM 依赖

在 Xcode 中：
```
File → Add Packages...
输入：https://github.com/FolioReader/FolioReaderKit
选择：Latest Version Up to Next Major
```

或使用 Swift Package Manager：
```swift
// Package.dependencies
.package(url: "https://github.com/FolioReader/FolioReaderKit.git", from: "0.9.0")
```

---

## 📝 第二步：实现 EPUBParser

创建文件：`Core/Parser/EPUBParser.swift`

```swift
import Foundation
import FolioReaderKit

/// EPUB 解析器
class EPUBParser {
    
    // MARK: - 解析结果
    struct EPUBBook {
        let title: String
        let author: String
        let coverImage: Data?
        let chapters: [EPUBChapter]
        let metadata: [String: String]
    }
    
    struct EPUBChapter {
        let title: String
        let href: String
        let content: String
        let index: Int
    }
    
    // MARK: - 解析 EPUB
    static func parse(file url: URL) async throws -> EPUBBook {
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw EPUBError.fileNotFound
        }
        
        // 使用 FolioReader 解析
        let book = FolioReader.shared.loadBook(url)
        
        // 提取元数据
        let title = book.title ?? "未知书籍"
        let author = book.creator ?? "未知作者"
        
        // 提取封面
        var coverData: Data?
        if let coverPath = book.cover {
            let coverURL = URL(fileURLWithPath: coverPath)
            coverData = try? Data(contentsOf: coverURL)
        }
        
        // 提取目录
        var chapters: [EPUBChapter] = []
        let toc = book.tableOfContents
        
        for (index, item) in toc.enumerated() {
            let chapter = try await parseChapter(
                book: book,
                href: item.href,
                title: item.title ?? "第 \(index + 1) 章",
                index: index
            )
            chapters.append(chapter)
        }
        
        // 提取其他元数据
        var metadata: [String: String] = [:]
        metadata["publisher"] = book.publisher
        metadata["language"] = book.language
        metadata["description"] = book.description
        metadata["rights"] = book.rights
        
        return EPUBBook(
            title: title,
            author: author,
            coverImage: coverData,
            chapters: chapters,
            metadata: metadata
        )
    }
    
    // MARK: - 解析章节
    private static func parseChapter(
        book: FolioReaderBook,
        href: String,
        title: String,
        index: Int
    ) async throws -> EPUBChapter {
        // 读取章节内容
        let content = try book.readChapter(at: href)
        
        return EPUBChapter(
            title: title,
            href: href,
            content: content,
            index: index
        )
    }
}

// MARK: - 错误类型
enum EPUBError: LocalizedError {
    case fileNotFound
    case invalidFormat
    case parseFailed(String)
    case chapterNotFound
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound: return "EPUB 文件不存在"
        case .invalidFormat: return "无效的 EPUB 格式"
        case .parseFailed(let reason): return "解析失败：\(reason)"
        case .chapterNotFound: return "章节不存在"
        }
    }
}
```

---

## 📝 第三步：更新 LocalBookViewModel

修改：`Features/Local/LocalBookViewModel.swift`

```swift
// 替换原来的 parseEPUB 方法
private func parseEPUB(file url: URL, book: Book) async throws {
    // 使用 EPUBParser 解析
    let epubBook = try await EPUBParser.parse(file: url)
    
    // 设置书籍信息
    book.name = epubBook.title
    book.author = epubBook.author
    book.totalChapterNum = Int32(epubBook.chapters.count)
    
    // 保存封面（如果有）
    if let coverData = epubBook.coverImage {
        // 保存到沙盒目录
        let coverURL = try await saveCoverImage(coverData, bookId: book.bookId)
        book.coverUrl = coverURL.path
    }
    
    // 创建章节记录
    let context = CoreDataStack.shared.viewContext
    for chapter in epubBook.chapters {
        let bookChapter = BookChapter.create(
            in: context,
            bookId: book.bookId,
            url: chapter.href,
            index: Int32(chapter.index),
            title: chapter.title
        )
        bookChapter.wordCount = Int32(chapter.content.count)
        bookChapter.isCached = true  // EPUB 内容已嵌入
    }
    
    // 保存元数据
    if let description = epubBook.metadata["description"] {
        book.intro = description
    }
    
    // 设置第一章为当前
    book.durChapterIndex = 0
    if let firstChapter = epubBook.chapters.first {
        book.durChapterTitle = firstChapter.title
    }
}

// MARK: - 保存封面图片
private func saveCoverImage(_ data: Data, bookId: UUID) async throws -> URL {
    let fileManager = FileManager.default
    let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let bookDir = documentsPath.appendingPathComponent("covers", isDirectory: true)
    
    // 创建目录
    if !fileManager.fileExists(atPath: bookDir.path) {
        try fileManager.createDirectory(at: bookDir, withIntermediateDirectories: true)
    }
    
    // 保存文件
    let coverURL = bookDir.appendingPathComponent("\(bookId.uuidString).jpg")
    try data.write(to: coverURL)
    
    return coverURL
}
```

---

## 📝 第四步：创建 EPUB 缓存管理器

创建文件：`Core/Cache/EPUBCacheManager.swift`

```swift
import Foundation

/// EPUB 缓存管理器
class EPUBCacheManager {
    static let shared = EPUBCacheManager()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    init() {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("epub", isDirectory: true)
        
        // 创建缓存目录
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(
                at: cacheDirectory,
                withIntermediateDirectories: true
            )
        }
    }
    
    // MARK: - 缓存 EPUB 文件
    func cacheEPUB(from sourceURL: URL, bookId: UUID) throws -> URL {
        let destURL = cacheDirectory.appendingPathComponent("\(bookId.uuidString).epub")
        
        // 如果已存在，直接返回
        if fileManager.fileExists(atPath: destURL.path) {
            return destURL
        }
        
        // 复制文件到缓存
        try fileManager.copyItem(at: sourceURL, to: destURL)
        return destURL
    }
    
    // MARK: - 获取缓存的 EPUB
    func getCachedEPUB(bookId: UUID) -> URL? {
        let url = cacheDirectory.appendingPathComponent("\(bookId.uuidString).epub")
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }
    
    // MARK: - 删除缓存
    func removeCache(bookId: UUID) {
        let epubURL = cacheDirectory.appendingPathComponent("\(bookId.uuidString).epub")
        try? fileManager.removeItem(at: epubURL)
        
        // 删除封面
        let coverURL = cacheDirectory.appendingPathComponent("\(bookId.uuidString).jpg")
        try? fileManager.removeItem(at: coverURL)
    }
    
    // MARK: - 清理所有缓存
    func clearAllCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        
        // 重新创建目录
        try? fileManager.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )
    }
    
    // MARK: - 获取缓存大小
    func getCacheSize() -> Int64 {
        var totalSize: Int64 = 0
        
        if let enumerator = fileManager.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(
                    forKeys: [.fileSizeKey]
                ).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }
        
        return totalSize
    }
}
```

---

## 📝 第五步：更新导入流程

修改：`Features/Local/LocalBookView.swift`

```swift
// 更新 importBook 方法
func importBook(url: URL) async throws -> Book {
    isImporting = true
    
    do {
        let context = CoreDataStack.shared.viewContext
        let book = Book.create(in: context)
        
        let fileExtension = url.pathExtension.lowercased()
        
        // 设置基本信息
        book.name = url.deletingPathExtension().lastPathComponent
        book.author = "未知"
        book.origin = "local"
        book.originName = url.lastPathComponent
        book.bookUrl = url.path
        book.canUpdate = false
        
        // 缓存 EPUB 文件
        if fileExtension == "epub" {
            let cachedURL = try EPUBCacheManager.shared.cacheEPUB(
                from: url,
                bookId: book.bookId
            )
            book.bookUrl = cachedURL.path
            book.type = 0  // text
        }
        
        // 根据类型解析
        if fileExtension == "txt" {
            try await parseTXT(file: url, book: book)
        } else if fileExtension == "epub" {
            try await parseEPUB(file: url, book: book)
        } else {
            throw LocalBookError.unsupportedFormat
        }
        
        try CoreDataStack.shared.save()
        
        isImporting = false
        await loadLocalBooks()
        
        return book
    } catch {
        isImporting = false
        throw error
    }
}
```

---

## ✅ 完成检查清单

- [ ] 添加 FolioReaderKit SPM 依赖
- [ ] 创建 EPUBParser.swift
- [ ] 更新 LocalBookViewModel.parseEPUB()
- [ ] 创建 EPUBCacheManager.swift
- [ ] 更新导入流程
- [ ] 测试 EPUB 导入
- [ ] 测试章节显示
- [ ] 测试封面显示

---

## 🎯 预期效果

完成后：
- ✅ 支持 EPUB 2/3 格式
- ✅ 自动提取书名、作者、封面
- ✅ 完整目录解析
- ✅ 章节内容缓存
- ✅ 支持离线阅读
- ✅ 缓存管理

---

*实施时间：预计 2-3 小时*

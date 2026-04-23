//
//  BookExtensions.swift
//  Legado-iOS
//
//  Book 实用扩展方法 — 1:1 对标 Android BookExtensions.kt
//  补充 Book 实体中缺少的工具方法
//

import Foundation
import CoreData

// MARK: - Book 类型判断扩展（对标 Android BookType）

extension Book {
    
    /// 音频书
    var isAudio: Bool {
        return isType(bookType: .audio)
    }
    
    /// 图片书（漫画）
    var isImage: Bool {
        return isType(bookType: .image)
    }
    
    /// 本地 TXT
    var isLocalTxt: Bool {
        return isLocal && originName.lowercased().hasSuffix(".txt")
    }
    
    /// 本地 EPUB
    var isEpub: Bool {
        return isLocal && originName.lowercased().hasSuffix(".epub")
    }
    
    /// 本地 UMD
    var isUmd: Bool {
        return isLocal && originName.lowercased().hasSuffix(".umd")
    }
    
    /// 本地 PDF
    var isPdf: Bool {
        return isLocal && originName.lowercased().hasSuffix(".pdf")
    }
    
    /// 本地 Mobi/AZW3/AZW
    var isMobi: Bool {
        return isLocal && (
            originName.lowercased().hasSuffix(".mobi") ||
            originName.lowercased().hasSuffix(".azw3") ||
            originName.lowercased().hasSuffix(".azw")
        )
    }
    
    /// 在线 TXT
    var isOnLineTxt: Bool {
        return !isLocal && isType(bookType: .text)
    }
    
    /// Web 文件类型
    var isWebFile: Bool {
        return isType(bookType: .webFile)
    }
    
    /// 更新错误标记
    var isUpError: Bool {
        return isType(bookType: .updateError)
    }
    
    /// 压缩包类型
    var isArchive: Bool {
        return isType(bookType: .archive)
    }
    
    // MARK: - BookType 枚举（对标 Android BookType）
    
    enum BookType: Int32 {
        case text = 0b1             // 1: 在线文本
        case audio = 0b10           // 2: 音频
        case image = 0b100          // 4: 图片/漫画
        case local = 0b1000         // 8: 本地
        case webFile = 0b10000      // 16: Web 文件
        case updateError = 0b100000  // 32: 更新错误
        case archive = 0b1000000    // 64: 压缩包
        case notShelf = 0b10000000  // 128: 不在书架
        
        static let allBookType: Int32 = 0b11111111
    }
    
    /// 判断书籍是否包含指定类型
    func isType(bookType: BookType) -> Bool {
        return (type & bookType.rawValue) > 0
    }
    
    /// 设置书籍类型
    func setType(bookTypes: Book.BookType...) {
        type = 0
        addType(bookTypes: bookTypes)
    }
    
    /// 添加类型标记
    func addType(bookTypes: Book.BookType...) {
        for bt in bookTypes {
            type = type | bt.rawValue
        }
    }
    
    /// 移除类型标记
    func removeType(bookTypes: Book.BookType...) {
        for bt in bookTypes {
            type = type & ~bt.rawValue
        }
    }
    
    /// 移除所有书籍类型
    func removeAllBookType() {
        removeType(bookTypes: .text, .audio, .image, .local, .webFile, .updateError, .archive, .notShelf)
    }
    
    /// 清空类型
    func clearType() {
        type = 0
    }
    
    /// 根据来源类型升级 type 值（对标 Android Book.upType）
    func upType() {
        if type < 8 {
            switch type {
            case 2: type = Book.BookType.audio.rawValue | (isLocal ? Book.BookType.local.rawValue : 0)
            case 4: type = Book.BookType.image.rawValue | (isLocal ? Book.BookType.local.rawValue : 0)
            case 16: type = Book.BookType.webFile.rawValue
            default: type = Book.BookType.text.rawValue | (isLocal ? Book.BookType.local.rawValue : 0)
            }
        }
    }
}

// MARK: - Book 搜索匹配扩展（对标 Android Book.contains）

extension Book {
    
    /// 关键词搜索匹配 — 对标 Android Book.contains(word)
    func contains(keyword: String?) -> Bool {
        guard let word = keyword, !word.isEmpty else { return true }
        if name.contains(word) { return true }
        if author.contains(word) { return true }
        if originName.contains(word) { return true }
        if origin.contains(word) { return true }
        if let kind = kind, kind.contains(word) { return true }
        if let intro = intro, intro.contains(word) { return true }
        return false
    }
}

// MARK: - Book 属性更新扩展（对标 Android Book.updateTo）

extension Book {
    
    /// 将旧书籍的阅读状态更新到新书籍 — 对标 Android Book.updateTo()
    func updateFrom(oldBook: Book) -> Book {
        durChapterIndex = oldBook.durChapterIndex
        durChapterTitle = oldBook.durChapterTitle
        durChapterPos = oldBook.durChapterPos
        durChapterTime = oldBook.durChapterTime
        group = oldBook.group
        order = oldBook.order
        canUpdate = oldBook.canUpdate
        
        // 合并 variable（保留旧书中新书没有的变量）
        if let oldVariable = oldBook.variable {
            var oldMap = (try? JSONDecoder().decode([String: String].self, from: Data(oldVariable.utf8))) ?? [:]
            if let newVariable = variable {
                let newMap = (try? JSONDecoder().decode([String: String].self, from: Data(newVariable.utf8))) ?? [:]
                for (key, value) in newMap {
                    oldMap[key] = value
                }
            }
            if let encoded = try? JSONEncoder().encode(oldMap),
               let str = String(data: encoded, encoding: .utf8) {
                variable = str
            }
        }
        
        return self
    }
    
    /// 释放 HTML 缓存数据 — 对标 Android Book.releaseHtmlData()
    func releaseHtmlData() {
        infoHtml = nil
        tocHtml = nil
    }
    
    /// 判断是否同名同作者 — 对标 Android Book.isSameNameAuthor()
    func isSameNameAuthor(other: Any?) -> Bool {
        guard let otherBook = other as? Book else { return false }
        return name == otherBook.name && author == otherBook.author
    }
    
    /// 获取导出文件名 — 对标 Android Book.getExportFileName(suffix:)
    func getExportFileName(suffix: String) -> String {
        // 简化实现：不使用 JS 引擎，直接拼接
        return "\(name) 作者：\(realAuthor).\(suffix)"
    }
    
    /// 获取分卷导出文件名 — 对标 Android Book.getExportFileName(suffix:epubIndex:)
    func getExportFileName(suffix: String, epubIndex: Int) -> String {
        return "\(name) 作者：\(realAuthor) [\(epubIndex)].\(suffix)"
    }
    
    /// 获取文件夹名（无缓存） — 对标 Android Book.getFolderNameNoCache()
    func getFolderNameNoCache() -> String {
        let normalized = name.replacingOccurrences(of: "[\\\\/:*?\"<>|]", with: "", options: .regularExpression)
        let prefix = String(normalized.prefix(9))
        let hash = bookId.uuidString.prefix(8)
        return "\(prefix)_\(hash)"
    }
    
    /// 获取关联的书源 — 对标 Android Book.getBookSource()
    func getBookSource(context: NSManagedObjectContext) -> BookSource? {
        let request: NSFetchRequest<BookSource> = BookSource.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "bookSourceUrl == %@", origin)
        return try? context.fetch(request).first
    }
}

// MARK: - BookSourceType 枚举（对标 Android BookSourceType）

enum BookSourceType: Int32 {
    case text = 0      // 文本
    case audio = 1     // 音频
    case image = 2     // 图片/漫画
    case file = 3      // 文件
}
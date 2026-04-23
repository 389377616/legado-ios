//
//  CacheBookService.swift
//  Legado-iOS
//
//  缓存书籍服务 - 1:1 对齐 Android CacheBookService.kt
//

import Foundation
import CoreData

/// 缓存书籍服务 - 对应 Android CacheBookService
/// 后台批量下载书籍章节用于离线阅读
@MainActor
class CacheBookService: ObservableObject {
    
    static let shared = CacheBookService()
    
    // MARK: - 状态（对应 Android Companion + Service 字段）
    
    @Published var isRunning: Bool = false
    @Published var progressText: String = ""
    @Published var downloadSummary: String = ""
    @Published var cachedBooks: [String: CacheBookProgress] = [:]
    
    private var downloadTask: Task<Void, Never>?
    private var threadCount: Int = 4
    private var mutex = AsyncMutex()
    
    // MARK: - 缓存进度模型
    
    struct CacheBookProgress {
        let bookUrl: String
        let bookName: String
        var currentChapter: Int = 0
        var totalChapters: Int = 0
        var status: Status = .waiting
        
        enum Status: Equatable {
            case waiting
            case loading
            case caching
            case completed
            case failed(String)
            
            static func == (lhs: Status, rhs: Status) -> Bool {
                switch (lhs, rhs) {
                case (.waiting, .waiting), (.loading, .loading), (.caching, .caching), (.completed, .completed):
                    return true
                case (.failed(let a), .failed(let b)):
                    return a == b
                default:
                    return false
                }
            }
        }
        
        var progress: Double {
            guard totalChapters > 0 else { return 0 }
            return Double(currentChapter) / Double(totalChapters)
        }
        
        var displayText: String {
            switch status {
            case .waiting: return "《\(bookName)》等待中"
            case .loading: return "《\(bookName)》加载目录中…"
            case .caching: return "《\(bookName)》\(currentChapter)/\(totalChapters)"
            case .completed: return "《\(bookName)》缓存完成"
            case .failed(let msg): return "《\(bookName)》\(msg)"
            }
        }
    }
    
    private init() {}
    
    // MARK: - 公开方法（对应 Android onStartCommand）
    
    /// 添加下载任务（对应 Android addDownloadData）
    func addDownload(bookUrl: String, start: Int = 0, end: Int = -1) async {
        guard let book = fetchBook(bookUrl: bookUrl) else { return }
        
        var progress = CacheBookProgress(bookUrl: bookUrl, bookName: book.name ?? "")
        
        if cachedBooks[bookUrl] != nil {
            return // 已在队列中
        }
        
        cachedBooks[bookUrl] = progress
        
        // 加载目录（如果尚未缓存）
        let chapterCount = getChapterCount(bookUrl: bookUrl)
        
        if chapterCount == 0 {
            cachedBooks[bookUrl]?.status = .loading
            updateSummary()
            
            do {
                try await mutex.withLock {
                    // 尝试获取详情
                    if book.tocUrl.isEmpty {
                        if let source = book.source {
                            try await WebBook.getBookInfo(source: source, book: book)
                        }
                    }
                    // 获取目录
                    if let source = book.source {
                        let webChapters = try await WebBook.getChapterList(source: source, book: book)
                        // 将 WebChapter 转换为 BookChapter 并保存
                        let context = CoreDataStack.shared.viewContext
                        for webChapter in webChapters {
                            let chapter = BookChapter.create(in: context)
                            chapter.chapterUrl = webChapter.url
                            chapter.title = webChapter.title
                            chapter.index = Int32(webChapter.index)
                            chapter.isVIP = webChapter.isVip
                            chapter.bookId = book.bookId
                            chapter.book = book
                        }
                        try? context.save()
                    }
                }
            } catch {
                cachedBooks[bookUrl]?.status = .failed("目录加载失败: \(error.localizedDescription)")
                updateSummary()
                return
            }
        }
        
        // 计算范围
        let end2 = end < 0 ? Int(book.lastChapterIndex) : min(end, Int(book.lastChapterIndex))
        cachedBooks[bookUrl]?.totalChapters = end2 - start
        cachedBooks[bookUrl]?.status = .caching
        
        updateSummary()
        
        // 启动下载
        if downloadTask == nil {
            await download(start: start, end: end2, bookUrl: bookUrl)
        }
    }
    
    /// 移除下载（对应 Android removeDownload）
    func removeDownload(bookUrl: String?) {
        guard let bookUrl = bookUrl else { return }
        cachedBooks.removeValue(forKey: bookUrl)
        updateSummary()
        
        if cachedBooks.isEmpty {
            stop()
        }
    }
    
    /// 停止服务（对应 Android onDestroy）
    func stop() {
        downloadTask?.cancel()
        downloadTask = nil
        cachedBooks.removeAll()
        isRunning = false
        downloadSummary = ""
        NotificationCenter.default.post(name: .cacheBookDone, object: nil)
    }
    
    // MARK: - 下载执行（对应 Android download + CacheBook.startProcessJob）
    
    private func download(start: Int, end: Int, bookUrl: String) async {
        isRunning = true
        
        downloadTask = Task { [weak self] in
            guard let self = self else { return }
            
            let context = CoreDataStack.shared.viewContext
            
            for (bookUrl, progress) in self.cachedBooks {
                guard !Task.isCancelled else { break }
                guard progress.status == .caching else { continue }
                
                // 获取章节列表
                guard let book = fetchBook(bookUrl: bookUrl) else { continue }
                let request: NSFetchRequest<BookChapter> = BookChapter.fetchRequest()
                request.predicate = NSPredicate(format: "bookId == %@", book.bookId as CVarArg)
                request.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]
                
                guard let chapters = try? context.fetch(request) else { continue }
                let targetChapters = chapters.filter { $0.index >= start && Int($0.index) <= end }
                
                var cached = 0
                self.cachedBooks[bookUrl]?.totalChapters = targetChapters.count
                
                for chapter in targetChapters {
                    guard !Task.isCancelled else { break }
                    
                    do {
                        try await self.cacheChapter(chapter, bookUrl: bookUrl)
                        cached += 1
                        self.cachedBooks[bookUrl]?.currentChapter = cached
                        self.updateSummary()
                        NotificationCenter.default.post(name: .cacheBookProgress, object: bookUrl)
                    } catch {
                        // 跳过失败章节继续
                        cached += 1
                        continue
                    }
                }
                
                if cached >= targetChapters.count {
                    self.cachedBooks[bookUrl]?.status = .completed
                }
            }
            
            self.isRunning = false
            self.downloadSummary = "缓存完成"
            NotificationCenter.default.post(name: .cacheBookDone, object: nil)
        }
        
        await downloadTask?.value
    }
    
    // MARK: - 缓存单章节（对应 Android CacheBook 下载+保存）
    
    private func cacheChapter(_ chapter: BookChapter, bookUrl: String) async throws {
        guard let book = fetchBook(bookUrl: bookUrl),
              let source = book.source else {
            throw CacheBookError.noSource
        }
        
        // 尚未缓存才下载
        if chapter.isCached { return }
        
        let content = try await WebBook.getContent(
            source: source,
            book: book,
            chapter: chapter
        )
        
        // 保存到缓存目录
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("ChapterCache") else { return }
        
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let fileURL = cacheDir.appendingPathComponent("\(chapter.chapterId.uuidString).txt")
        try content.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
        
        // 更新章节缓存状态
        chapter.cachePath = fileURL.path
        chapter.isCached = true
        try CoreDataStack.shared.viewContext.save()
    }
    
    // MARK: - 辅助方法
    
    private func fetchBook(bookUrl: String) -> Book? {
        let context = CoreDataStack.shared.viewContext
        let request: NSFetchRequest<Book> = Book.fetchRequest()
        request.predicate = NSPredicate(format: "bookUrl == %@", bookUrl)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
    
    private func getChapterCount(bookUrl: String) -> Int {
        let context = CoreDataStack.shared.viewContext
        guard let book = fetchBook(bookUrl: bookUrl) else { return 0 }
        let request: NSFetchRequest<BookChapter> = BookChapter.fetchRequest()
        request.predicate = NSPredicate(format: "bookId == %@", book.bookId as CVarArg)
        return (try? context.count(for: request)) ?? 0
    }
    
    private func saveChapters(_ chapters: [BookChapter], for bookUrl: String) {
        let context = CoreDataStack.shared.viewContext
        for chapter in chapters {
            context.insert(chapter)
        }
        try? context.save()
    }
    
    private func updateSummary() {
        downloadSummary = cachedBooks.values.map { $0.displayText }.joined(separator: "\n")
    }
}

// MARK: - 简易异步互斥锁

private class AsyncMutex {
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var isLocked = false
    
    func withLock<T>(_ block: () async throws -> T) async rethrows -> T {
        await acquire()
        defer { release() }
        return try await block()
    }
    
    private func acquire() async {
        if !isLocked {
            isLocked = true
            return
        }
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }
    
    private func release() {
        if let continuation = continuations.first {
            continuations.removeFirst()
            continuation.resume()
        } else {
            isLocked = false
        }
    }
}

// MARK: - 错误

private enum CacheBookError: LocalizedError {
    case noSource
    case bookNotFound
    
    var errorDescription: String? {
        switch self {
        case .noSource: return "没有书源"
        case .bookNotFound: return "书籍不存在"
        }
    }
}

// MARK: - 通知

extension Notification.Name {
    static let cacheBookProgress = Notification.Name("cacheBookProgress")
    static let cacheBookDone = Notification.Name("cacheBookDone")
}
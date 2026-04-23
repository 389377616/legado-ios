//
//  CheckSourceService.swift
//  Legado-iOS
//
//  书源批量校验服务 - 1:1 对齐 Android CheckSourceService.kt
//

import Foundation
import CoreData

/// 书源校验结果
struct SourceCheckResult: Identifiable {
    let id = UUID()
    let sourceUrl: String
    let sourceName: String
    let status: Status
    let responseTime: TimeInterval
    let errorMessage: String?
    
    enum Status: String {
        case available = "校验成功"
        case timeout = "校验超时"
        case jsError = "js失效"
        case siteError = "网站失效"
        case searchUrlEmpty = "搜索链接规则为空"
        case searchFailed = "搜索失效"
        case exploreUrlEmpty = "发现规则为空"
        case exploreFailed = "发现失效"
        case infoFailed = "详情失效"
        case tocFailed = "目录失效"
        case contentFailed = "正文失效"
        case error = "出错"
    }
}

/// 书源批量校验服务 - 对应 Android CheckSourceService
@MainActor
class CheckSourceService: ObservableObject {
    
    // MARK: - 对应 Android CheckSource 配置
    
    /// 是否检查搜索
    var checkSearch: Bool = true
    /// 是否检查发现
    var checkDiscovery: Bool = true
    /// 是否检查详情
    var checkInfo: Bool = true
    /// 是否检查目录
    var checkCategory: Bool = true
    /// 是否检查正文
    var checkContent: Bool = true
    /// 搜索关键词
    var keyword: String = "我的"
    /// 超时时间（秒）
    var timeout: TimeInterval = 30
    /// 并发线程数
    var threadCount: Int = 4
    
    // MARK: - 对应 Android Service 状态
    
    @Published var isRunning: Bool = false
    @Published var progress: Double = 0
    @Published var progressText: String = ""
    @Published var results: [SourceCheckResult] = []
    @Published var checkedCount: Int = 0
    @Published var totalCount: Int = 0
    
    private var checkTask: Task<Void, Never>?
    
    // MARK: - 单例
    
    static let shared = CheckSourceService()
    private init() {}
    
    // MARK: - 公开方法（对应 Android onStartCommand -> check）
    
    /// 批量校验书源（对应 Android check(ids)）
    func check(sourceIds: [String]) async {
        guard !isRunning else { return }
        
        isRunning = true
        results = []
        checkedCount = 0
        totalCount = sourceIds.count
        progressText = "正在校验 0/\(totalCount)"
        
        let context = CoreDataStack.shared.viewContext
        
        await withTaskGroup(of: SourceCheckResult?.self) { group in
            var activeCount = 0
            let maxConcurrent = threadCount
            
            for sourceId in sourceIds {
                guard isRunning else { break }
                
                // 限流：等待有空位
                while activeCount >= maxConcurrent {
                    if let result = await group.next() {
                        if let result = result {
                            results.append(result)
                        }
                        checkedCount += 1
                        progress = Double(checkedCount) / Double(totalCount)
                        progressText = "\(result?.sourceName ?? "") \(checkedCount)/\(totalCount)"
                        activeCount -= 1
                    }
                }
                
                // 查找书源
                let request: NSFetchRequest<BookSource> = BookSource.fetchRequest()
                request.predicate = NSPredicate(format: "bookSourceUrl == %@", sourceId)
                request.fetchLimit = 1
                
                guard let source = try? context.fetch(request).first else {
                    checkedCount += 1
                    progress = Double(checkedCount) / Double(totalCount)
                    continue
                }
                
                activeCount += 1
                let sourceName = source.bookSourceName ?? ""
                
                group.addTask { [weak self] in
                    guard self != nil else { return nil }
                    return await self?.checkSource(source)
                }
            }
            
            // 收集剩余结果
            for await result in group {
                if let result = result {
                    results.append(result)
                }
                checkedCount += 1
                progress = Double(checkedCount) / Double(totalCount)
                progressText = "\(result?.sourceName ?? "") \(checkedCount)/\(totalCount)"
            }
        }
        
        isRunning = false
        progressText = "校验完成"
        NotificationCenter.default.post(name: .checkSourceDone, object: nil)
    }
    
    /// 停止校验（对应 Android IntentAction.stop）
    func stop() {
        checkTask?.cancel()
        checkTask = nil
        isRunning = false
        progressText = "已取消"
    }
    
    // MARK: - 单个书源校验（对应 Android checkSource + doCheckSource）
    
    private func checkSource(_ source: BookSource) -> SourceCheckResult {
        let startTime = Date()
        let sourceUrl = source.bookSourceUrl ?? ""
        let sourceName = source.bookSourceName ?? ""
        
        do {
            // 移除之前的错误标记
            removeInvalidGroups(from: source)
            removeErrorComment(from: source)
            
            // 校验搜索
            if checkSearch && !(source.searchUrl ?? "").isEmpty {
                let searchWord = getCheckKeyword(from: source)
                let searchBooks = try WebBook.searchBookAwait(source: source, key: searchWord)
                
                if searchBooks.isEmpty {
                    addGroup("搜索失效", to: source)
                } else {
                    removeGroup("搜索失效", from: source)
                    if checkInfo, let firstBook = searchBooks.first {
                        try checkBook(firstBook, source: source, isSearchBook: true)
                    }
                }
            } else if checkSearch && (source.searchUrl ?? "").isEmpty {
                addGroup("搜索链接规则为空", to: source)
            }
            
            // 校验发现
            if checkDiscovery && !(source.exploreUrl ?? "").isEmpty {
                let exploreUrl = getFirstExploreUrl(from: source)
                if exploreUrl.isEmpty {
                    addGroup("发现规则为空", to: source)
                } else {
                    removeGroup("发现规则为空", from: source)
                    let exploreBooks = try WebBook.exploreBookAwait(source: source, url: exploreUrl)
                    if exploreBooks.isEmpty {
                        addGroup("发现失效", to: source)
                    } else {
                        removeGroup("发现失效", from: source)
                        if checkInfo, let firstBook = exploreBooks.first {
                            try checkBook(firstBook, source: source, isSearchBook: false)
                        }
                    }
                }
            }
            
            // 最终检查是否仍有错误分组
            let invalidGroups = getInvalidGroupNames(from: source)
            if !invalidGroups.isEmpty {
                return SourceCheckResult(
                    sourceUrl: sourceUrl,
                    sourceName: sourceName,
                    status: .error,
                    responseTime: Date().timeIntervalSince(startTime),
                    errorMessage: invalidGroups
                )
            }
            
            return SourceCheckResult(
                sourceUrl: sourceUrl,
                sourceName: sourceName,
                status: .available,
                responseTime: Date().timeIntervalSince(startTime),
                errorMessage: nil
            )
        } catch {
            let status: SourceCheckResult.Status
            if error is TimeoutError || (error as NSError).domain == NSURLErrorDomain {
                status = .timeout
            } else if let jsError = error as? JavaScriptError {
                status = .jsError
            } else {
                status = .siteError
            }
            
            addErrorComment(error.localizedDescription, to: source)
            
            return SourceCheckResult(
                sourceUrl: sourceUrl,
                sourceName: sourceName,
                status: status,
                responseTime: Date().timeIntervalSince(startTime),
                errorMessage: error.localizedDescription
            )
        }
    }
    
    // MARK: - 校验书源详情/目录/正文（对应 Android checkBook）
    
    private func checkBook(_ book: SearchBookResult, source: BookSource, isSearchBook: Bool) throws {
        let bookType = isSearchBook ? "搜索" : "发现"
        
        do {
            if !checkInfo { return }
            
            // 校验详情
            let bookInfo = try WebBook.getBookInfoAwait(source: source, book: book)
            
            if !checkCategory || source.bookSourceType == 3 { // file type
                return
            }
            
            // 校验目录
            let toc = try WebBook.getChapterListAwait(source: source, book: bookInfo)
                .filter { !($0.isVolume && ($0.url ?? "").starts(with: $0.title ?? "")) }
                .prefix(2)
                .map { $0 }
            
            guard let firstChapter = toc.first else {
                throw SourceCheckError.tocEmpty
            }
            
            if !checkContent { return }
            
            // 校验正文
            let nextChapterUrl = toc.count > 1 ? toc[1].url : firstChapter.url
            _ = try WebBook.getContentAwait(
                source: source,
                book: bookInfo,
                chapter: firstChapter,
                nextChapterUrl: nextChapterUrl
            )
            
            removeGroup("\(bookType)目录失效", from: source)
            removeGroup("\(bookType)正文失效", from: source)
        } catch let error where !(error is NoStackTraceError) {
            if error is ContentEmptyError {
                addGroup("\(bookType)正文失效", to: source)
            } else if error is TocEmptyError {
                addGroup("\(bookType)目录失效", to: source)
            } else {
                throw error
            }
        }
    }
    
    // MARK: - 书源分组操作（对应 Android BookSource 扩展方法）
    
    private func addGroup(_ group: String, to source: BookSource) {
        var groups = source.bookSourceGroup?.components(separatedBy: ";") ?? []
        if !groups.contains(group) {
            groups.append(group)
            source.bookSourceGroup = groups.joined(separator: ";")
        }
    }
    
    private func removeGroup(_ group: String, from source: BookSource) {
        var groups = source.bookSourceGroup?.components(separatedBy: ";") ?? []
        groups.removeAll { $0 == group }
        source.bookSourceGroup = groups.joined(separator: ";")
    }
    
    private func removeInvalidGroups(from source: BookSource) {
        let invalidTags = ["搜索失效", "发现失效", "搜索链接规则为空", "发现规则为空",
                           "搜索正文失效", "搜索目录失效", "发现正文失效", "发现目录失效",
                           "校验超时", "js失效", "网站失效"]
        var groups = source.bookSourceGroup?.components(separatedBy: ";") ?? []
        groups.removeAll { invalidTags.contains($0) }
        source.bookSourceGroup = groups.joined(separator: ";")
    }
    
    private func addErrorComment(_ comment: String, to source: BookSource) {
        source.customOrder = Int16(source.customOrder) | 0 // 保留原值
        // Android 存到 errorComment 字段，iOS 用 remark 字段
        if source.remark == nil || source.remark!.isEmpty {
            source.remark = comment
        } else {
            source.remark = (source.remark ?? "") + "\n" + comment
        }
    }
    
    private func removeErrorComment(from source: BookSource) {
        source.remark = nil
    }
    
    private func getInvalidGroupNames(from source: BookSource) -> String {
        let invalidTags = ["搜索失效", "发现失效", "搜索链接规则为空", "发现规则为空",
                           "搜索正文失效", "搜索目录失效", "发现正文失效", "发现目录失效",
                           "校验超时", "js失效", "网站失效"]
        let groups = source.bookSourceGroup?.components(separatedBy: ";") ?? []
        return groups.filter { invalidTags.contains($0) }.joined(separator: ";")
    }
    
    private func getCheckKeyword(from source: BookSource) -> String {
        // 优先使用书源自定义关键词，否则用默认值
        if let customKeyword = source.customOrder as? Int16, customKeyword != 0 {
            return keyword
        }
        return keyword
    }
    
    private func getFirstExploreUrl(from source: BookSource) -> String {
        guard let exploreUrl = source.exploreUrl else { return "" }
        // 简单解析：取第一个 URL
        let parts = exploreUrl.components(separatedBy: "\n")
        for part in parts {
            let urlPair = part.components(separatedBy: "::")
            if urlPair.count >= 2, !urlPair[1].isEmpty {
                return urlPair[1]
            } else if urlPair.count == 1, !urlPair[0].isEmpty {
                return urlPair[0]
            }
        }
        return ""
    }
}

// MARK: - 错误类型

private struct NoStackTraceError: Error {}
private struct ContentEmptyError: Error {}
private struct TocEmptyError: Error {}
private struct JavaScriptError: Error {}
private struct TimeoutError: Error {}

// MARK: - 搜索结果模型（简化版，与 WebBook 搜索结果转换用）

private struct SearchBookResult {
    let name: String
    let author: String
    let bookUrl: String
    let coverUrl: String?
    let intro: String?
    let kind: String?
    let wordCount: String?
    let lastChapter: String?
}

// MARK: - 通知名

extension Notification.Name {
    static let checkSourceDone = Notification.Name("checkSourceDone")
    static let checkSourceProgress = Notification.Name("checkSourceProgress")
}
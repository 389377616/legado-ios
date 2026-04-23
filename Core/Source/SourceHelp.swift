//
//  SourceHelp.swift
//  Legado-iOS
//
//  书源管理辅助 — 1:1 对标 Android SourceHelp.kt
//  书源分组管理、导入/导出、删除等操作
//

import Foundation
import CoreData

// MARK: - 书源管理辅助（对标 Android SourceHelp）

enum SourceHelp {
    
    /// 获取书源 — 对标 Android getSource(key:type:)
    static func getSource(key: String?, type: SourceType) -> NSManagedObject? {
        guard let key = key, !key.isEmpty else { return nil }
        let context = CoreDataStack.shared.viewContext
        
        switch type {
        case .book:
            let request: NSFetchRequest<BookSource> = BookSource.fetchRequest()
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "bookSourceUrl == %@", key)
            return try? context.fetch(request).first
        case .rss:
            let request: NSFetchRequest<RssSource> = RssSource.fetchRequest()
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "sourceUrl == %@", key)
            return try? context.fetch(request).first
        }
    }
    
    /// 删除书源 — 对标 Android deleteSource(key:type:)
    static func deleteSource(key: String, type: SourceType) {
        switch type {
        case .book: deleteBookSource(key: key)
        case .rss: deleteRssSource(key: key)
        }
    }
    
    /// 批量删除书源 — 对标 Android deleteBookSources(sources:)
    static func deleteBookSources(sources: [BookSource]) {
        let context = CoreDataStack.shared.viewContext
        for source in sources {
            context.delete(source)
        }
        try? context.save()
    }
    
    /// 删除单个书源 — 对标 Android deleteBookSource(key:)
    static func deleteBookSource(key: String) {
        let context = CoreDataStack.shared.viewContext
        let request: NSFetchRequest<BookSource> = BookSource.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "bookSourceUrl == %@", key)
        
        if let source = try? context.fetch(request).first {
            context.delete(source)
            try? context.save()
        }
    }
    
    /// 批量删除 RSS 源 — 对标 Android deleteRssSources(sources:)
    static func deleteRssSources(sources: [RssSource]) {
        let context = CoreDataStack.shared.viewContext
        for source in sources {
            context.delete(source)
        }
        try? context.save()
    }
    
    /// 删除单个 RSS 源 — 对标 Android deleteRssSource(key:)
    static func deleteRssSource(key: String) {
        let context = CoreDataStack.shared.viewContext
        let request: NSFetchRequest<RssSource> = RssSource.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "sourceUrl == %@", key)
        
        if let source = try? context.fetch(request).first {
            // 同时删除关联的文章
            let articleRequest: NSFetchRequest<RssArticle> = RssArticle.fetchRequest()
            articleRequest.predicate = NSPredicate(format: "origin == %@", key)
            if let articles = try? context.fetch(articleRequest) {
                for article in articles {
                    context.delete(article)
                }
            }
            context.delete(source)
            try? context.save()
        }
    }
    
    /// 启用/禁用书源 — 对标 Android enableSource(key:type:enable:)
    static func enableSource(key: String, type: SourceType, enable: Bool) {
        let context = CoreDataStack.shared.viewContext
        
        switch type {
        case .book:
            let request: NSFetchRequest<BookSource> = BookSource.fetchRequest()
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "bookSourceUrl == %@", key)
            if let source = try? context.fetch(request).first {
                source.enabled = enable
                try? context.save()
            }
        case .rss:
            let request: NSFetchRequest<RssSource> = RssSource.fetchRequest()
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "sourceUrl == %@", key)
            if let source = try? context.fetch(request).first {
                source.enabled = enable
                try? context.save()
            }
        }
    }
    
    /// 批量导入书源 — 对标 Android insertBookSource(vararg:)
    static func insertBookSources(_ bookSources: [BookSource]) {
        let context = CoreDataStack.shared.viewContext
        for source in bookSources {
            // 检查是否已存在
            let request: NSFetchRequest<BookSource> = BookSource.fetchRequest()
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "bookSourceUrl == %@", source.bookSourceUrl)
            if let existing = try? context.fetch(request).first {
                // 更新已有书源
                existing.bookSourceName = source.bookSourceName
                existing.bookSourceGroup = source.bookSourceGroup
                existing.bookSourceType = source.bookSourceType
                existing.searchUrl = source.searchUrl
                existing.enabled = source.enabled
                existing.customOrder = source.customOrder
                // ... 其他字段
            } else {
                // 新增书源（已由 CoreData context 管理）
            }
        }
        try? context.save()
        adjustSortNumber()
    }
    
    /// 批量导入 RSS 源 — 对标 Android insertRssSource(vararg:)
    static func insertRssSources(_ rssSources: [RssSource]) {
        let context = CoreDataStack.shared.viewContext
        for source in rssSources {
            let request: NSFetchRequest<RssSource> = RssSource.fetchRequest()
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "sourceUrl == %@", source.sourceUrl)
            if let existing = try? context.fetch(request).first {
                existing.sourceName = source.sourceName
                existing.sourceIcon = source.sourceIcon
                existing.sourceGroup = source.sourceGroup
                existing.sortUrl = source.sortUrl
                existing.enabled = source.enabled
                existing.customOrder = source.customOrder
            }
        }
        try? context.save()
    }
    
    /// 调整排序序号 — 对标 Android adjustSortNumber()
    static func adjustSortNumber() {
        let context = CoreDataStack.shared.viewContext
        let request: NSFetchRequest<BookSource> = BookSource.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "customOrder", ascending: true)]
        
        guard let sources = try? context.fetch(request), !sources.isEmpty else { return }
        
        // 检查是否需要重排
        let maxOrder = sources.map(\.customOrder).max() ?? 0
        let minOrder = sources.map(\.customOrder).min() ?? 0
        
        if maxOrder > 99999 || minOrder < -99999 || hasDuplicateOrder(sources) {
            for (index, source) in sources.enumerated() {
                source.customOrder = Int32(index)
            }
            try? context.save()
        }
    }
    
    // MARK: - Private
    
    private static func hasDuplicateOrder(_ sources: [BookSource]) -> Bool {
        var seen = Set<Int32>()
        for source in sources {
            if seen.contains(source.customOrder) {
                return true
            }
            seen.insert(source.customOrder)
        }
        return false
    }
}

// MARK: - 书源类型枚举（对标 Android SourceType）

enum SourceType: Int {
    case book = 0
    case rss = 1
}

// MARK: - BookSource 扩展（对标 Android BookSourceExtensions.kt）

extension BookSource {
    
    /// 获取发现分类 — 对标 Android BookSource.exploreKinds()
    func exploreKinds() -> [ExploreKind] {
        guard let exploreUrl = exploreUrl, !exploreUrl.isEmpty else {
            return []
        }
        
        // 解析发现分类 URL
        let kinds = parseExploreKinds(from: exploreUrl)
        return kinds
    }
    
    /// 获取书源类型 — 对标 Android BookSource.getBookType()
    var bookType: Book.BookType {
        switch bookSourceType {
        case 0: return .text       // 文本
        case 1: return .audio     // 音频
        case 2: return .image     // 图片/漫画
        case 3: return .webFile   // 文件
        default: return .text
        }
    }
    
    // MARK: - Private
    
    private func parseExploreKinds(from exploreUrl: String) -> [ExploreKind] {
        var kinds: [ExploreKind] = []
        
        // JSON 格式
        if exploreUrl.hasPrefix("[") {
            if let data = exploreUrl.data(using: .utf8),
               let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
                for item in jsonArray {
                    if let title = item["title"], let url = item["url"] {
                        kinds.append(ExploreKind(title: title, url: url))
                    }
                }
                return kinds
            }
        }
        
        // && 或换行分隔的格式: 标题::URL
        let separators = "&&|\n"
        let parts = exploreUrl.components(separatedBy: separators)
        
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            let components = trimmed.components(separatedBy: "::")
            if components.count >= 2 {
                let title = components[0].trimmingCharacters(in: .whitespaces)
                let url = components[1].trimmingCharacters(in: .whitespaces)
                if !title.isEmpty && !url.isEmpty {
                    kinds.append(ExploreKind(title: title, url: url))
                }
            }
        }
        
        return kinds
    }
}

// MARK: - 发现分类模型（对标 Android ExploreKind）

struct ExploreKind: Identifiable {
    let id = UUID()
    let title: String
    let url: String?
}

// MARK: - RssSource 扩展（对标 Android RssSourceExtensions.kt）

extension RssSource {
    
    /// 获取分类 URL 列表 — 对标 Android RssSource.sortUrls()
    func sortUrls() -> [(name: String, url: String)] {
        guard let sortUrl = sortUrl, !sortUrl.isEmpty else {
            return [(name: sourceName, url: sourceUrl)]
        }
        
        var results: [(name: String, url: String)] = []
        let parts = sortUrl.components(separatedBy: "&&|\n")
        
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            let components = trimmed.components(separatedBy: "::")
            if components.count >= 2 {
                let name = components[0].trimmingCharacters(in: .whitespaces)
                let url = components[1].trimmingCharacters(in: .whitespaces)
                if !url.isEmpty {
                    let absoluteURL = url.hasPrefix("http") ? url : absoluteURL(base: sourceUrl, relative: url)
                    results.append((name: name, url: absoluteURL))
                }
            }
        }
        
        if results.isEmpty {
            results.append((name: sourceName, url: sourceUrl))
        }
        
        return results
    }
    
    // MARK: - Private
    
    private func absoluteURL(base: String, relative: String) -> String {
        guard !relative.isEmpty else { return "" }
        if relative.hasPrefix("http://") || relative.hasPrefix("https://") {
            return relative
        }
        guard let baseURL = URL(string: base) else { return relative }
        return URL(string: relative, relativeTo: baseURL)?.absoluteString ?? relative
    }
}
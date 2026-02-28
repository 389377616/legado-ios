//
//  SearchViewModel.swift
//  Legado-iOS
//
//  搜索 ViewModel
//

import Foundation
import CoreData

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var selectedSources: [BookSource] = []
    
    private var ruleEngine: RuleEngine = RuleEngine()
    
    // MARK: - 搜索结果
    struct SearchResult: Identifiable {
        let id = UUID()
        let name: String
        let author: String
        let coverUrl: String?
        let intro: String?
        let sourceName: String
        let sourceId: UUID
        let bookUrl: String
        
        var displayName: String {
            name.trimmingCharacters(in: .whitespaces)
        }
        
        var displayAuthor: String {
            author.trimmingCharacters(in: .whitespaces)
        }
    }
    
    // MARK: - 执行搜索
    func search(keyword: String, sources: [BookSource]) async {
        guard !keyword.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        searchResults.removeAll()
        errorMessage = nil

        let enabledSources = sources.filter { $0.enabled && $0.searchUrl != nil }
        var merged: [SearchResult] = []

        await withTaskGroup(of: [SearchResult].self) { group in
            for source in enabledSources {
                group.addTask { [keyword] in
                    do {
                        return try await self.searchInSource(keyword: keyword, source: source)
                    } catch {
                        return []
                    }
                }
            }

            for await partial in group {
                merged.append(contentsOf: partial)
            }
        }

        searchResults = merged
        isSearching = false
    }
    
    // MARK: - 在单个书源中搜索
    private func searchInSource(keyword: String, source: BookSource) async throws -> [SearchResult] {
        // 使用 WebBook 进行搜索
        let results = try await WebBook.searchBook(source: source, key: keyword)
        
        return results.map { searchBook in
            SearchResult(
                name: searchBook.name,
                author: searchBook.author,
                coverUrl: searchBook.coverUrl,
                intro: searchBook.intro,
                sourceName: source.bookSourceName,
                sourceId: source.sourceId,
                bookUrl: searchBook.bookUrl
            )
        }
    }
    
    // MARK: - 添加到书架
    func addToBookshelf(result: SearchResult) async throws {
        let context = CoreDataStack.shared.viewContext
        let book = Book.create(in: context)
        
        book.name = result.name
        book.author = result.author
        book.coverUrl = result.coverUrl
        book.intro = "..."
        book.bookUrl = result.bookUrl
        book.tocUrl = ""
        book.origin = result.sourceId.uuidString
        book.originName = result.sourceName
        book.type = 0
        
        try CoreDataStack.shared.save()
    }
}

// MARK: - 错误类型
enum SearchError: LocalizedError {
    case invalidSource
    case noSearchRule
    case networkFailure
    
    var errorDescription: String? {
        switch self {
        case .invalidSource: return "书源无效"
        case .noSearchRule: return "缺少搜索规则"
        case .networkFailure: return "网络请求失败"
        }
    }
}

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
    private var searchTask: Task<Void, Never>?

    init() {
        loadDefaultSources()
    }

    private func loadDefaultSources() {
        do {
            let sources = try CoreDataStack.shared.viewContext.fetch(BookSource.fetchRequest())
            selectedSources = sources.filter { $0.enabled && $0.searchUrl != nil }
        } catch {
            selectedSources = []
        }
    }
    
    func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
        isSearching = false
    }
    
    struct SearchResult: Identifiable {
        let id = UUID()
        let name: String
        let author: String
        let coverUrl: String?
        let intro: String?
        let kind: String?
        let lastChapter: String?
        let sourceName: String
        let sourceId: UUID
        let bookUrl: String
        var sourceCount: Int = 1
        
        var displayName: String {
            name.trimmingCharacters(in: .whitespaces)
        }
        
        var displayAuthor: String {
            author.trimmingCharacters(in: .whitespaces)
        }
    }
    
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
    
    private func searchInSource(keyword: String, source: BookSource) async throws -> [SearchResult] {
        let results = try await WebBook.searchBook(source: source, key: keyword)
        
        return results.map { searchBook in
            SearchResult(
                name: searchBook.name,
                author: searchBook.author,
                coverUrl: searchBook.coverUrl,
                intro: searchBook.intro,
                kind: nil,
                lastChapter: searchBook.lastChapter,
                sourceName: source.bookSourceName,
                sourceId: source.sourceId,
                bookUrl: searchBook.bookUrl
            )
        }
    }
    
func addToBookshelf(result: SearchResult) async throws -> Book {
        let context = CoreDataStack.shared.viewContext
        
        let bookData = BookImportData(
            name: result.name,
            author: result.author,
            bookUrl: result.bookUrl,
            tocUrl: "",
            origin: result.sourceId.uuidString,
            originName: result.sourceName,
            coverUrl: result.coverUrl,
            intro: result.intro,
            latestChapterTitle: result.lastChapter
        )
        
        let book = try BookDeduplicator.importBook(bookData, context: context)
        
        let sourceRequest: NSFetchRequest<BookSource> = BookSource.fetchRequest()
        sourceRequest.fetchLimit = 1
        sourceRequest.predicate = NSPredicate(format: "sourceId == %@", result.sourceId as CVarArg)
        if let source = try? context.fetch(sourceRequest).first {
            book.source = source
        }
        
        try CoreDataStack.shared.save()
        return book
    }

    private func findBook(bookUrl: String, origin: String, in context: NSManagedObjectContext) -> Book? {
        let request: NSFetchRequest<Book> = Book.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "bookUrl == %@ AND origin == %@", bookUrl, origin)
        return try? context.fetch(request).first
    }
}

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

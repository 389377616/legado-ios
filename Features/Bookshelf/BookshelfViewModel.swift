//
//  BookshelfViewModel.swift
//  Legado-iOS
//
//  书架 ViewModel
//

import Foundation
import CoreData
import Combine

@MainActor
final class BookshelfViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasMore = true
    
    @Published var viewMode: ViewMode = .grid
    @Published var groupFilter: Int32 = 0
    @Published var sortBy: SortBy = .lastRead
    
    private let pageSize = 50
    private var currentPage = 0
    
    enum ViewMode: Int, CaseIterable {
        case grid = 0
        case list = 1
    }
    
    enum SortBy: Int, CaseIterable {
        case lastRead = 0
        case name = 1
        case author = 2
        case update = 3
    }
    
    private var loadTask: Task<Void, Never>?
    
    deinit {
        loadTask?.cancel()
    }
    
    func loadBooks() async {
        guard !isLoading else { return }

        isLoading = true
        currentPage = 0

        do {
            let firstPage = try await fetchBooks(page: 0, size: pageSize)
            print("📚 loadBooks: 获取到 \(firstPage.count) 本书")
            for book in firstPage.prefix(3) {
                print("  - \(book.name) (origin: \(book.origin))")
            }
            books = firstPage
            hasMore = firstPage.count == pageSize
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
            print("❌ loadBooks 失败: \(error)")
        }

        isLoading = false
    }
    
    func forceReload() async {
        print("🔄 forceReload: 强制刷新书架")
        isLoading = false
        
        let context = CoreDataStack.shared.viewContext
        context.refreshAllObjects()
        
        let request: NSFetchRequest<Book> = Book.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "durChapterTime", ascending: false)]
        
        do {
            let allBooks = try context.fetch(request)
            print("📊 forceReload: 直接查询到 \(allBooks.count) 本书")
            
            await MainActor.run {
                self.books = allBooks
                self.hasMore = allBooks.count >= pageSize
            }
        } catch {
            print("❌ forceReload 查询失败: \(error)")
            await loadBooks()
        }
    }
    
    func loadMoreBooks() async {
        guard !isLoading && hasMore else { return }

        isLoading = true

        do {
            currentPage += 1
            let nextPage = try await fetchBooks(page: currentPage, size: pageSize)
            books.append(contentsOf: nextPage)
            hasMore = nextPage.count == pageSize
        } catch {
            errorMessage = "加载更多失败：\(error.localizedDescription)"
        }

        isLoading = false
    }
    
    private func fetchBooks(page: Int, size: Int) async throws -> [Book] {
        let context = CoreDataStack.shared.viewContext

        let request: NSFetchRequest<Book> = Book.fetchRequest()
        request.fetchLimit = size
        request.fetchOffset = page * size
        request.returnsObjectsAsFaults = false

        if groupFilter != 0 {
            request.predicate = NSPredicate(format: "group == %d", groupFilter)
        }

        switch sortBy {
        case .lastRead:
            request.sortDescriptors = [NSSortDescriptor(key: "durChapterTime", ascending: false)]
        case .name:
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        case .author:
            request.sortDescriptors = [NSSortDescriptor(key: "author", ascending: true)]
        case .update:
            request.sortDescriptors = [NSSortDescriptor(key: "lastCheckTime", ascending: false)]
        }

        let results = try context.fetch(request)
        print("📊 fetchBooks: 查询到 \(results.count) 本书")
        return results
    }
    
    func refreshBooks() async {
        await loadBooks()
    }
    
    func removeBook(_ book: Book) {
        CoreDataStack.shared.viewContext.delete(book)
        try? CoreDataStack.shared.save()
    }
    
    func updateGroup(for book: Book, group: Int32) {
        book.group = Int64(group)
        try? CoreDataStack.shared.save()
    }
}
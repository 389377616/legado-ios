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

    @Published var debugDiskBookCount: Int = 0
    @Published var debugStorePath: String = ""
    @Published var coreDataStatus: String = ""
    
    init() {
        _ = CoreDataStack.shared.persistentContainer
        coreDataStatus = CoreDataStack.shared.debugInfo
    }
    
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
        coreDataStatus = CoreDataStack.shared.debugInfo

        do {
            debugStorePath = CoreDataStack.shared.storeURL?.path ?? ""

            let count = try await countBooks()
            let firstPage = try await fetchBooks(page: 0, size: pageSize)
            
            debugDiskBookCount = count
            books = firstPage
            hasMore = firstPage.count == pageSize
            
            DebugLogger.shared.log("loadBooks 完成: UI=\(firstPage.count), 磁盘=\(count)")
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
            DebugLogger.shared.log("loadBooks 失败: \(error)")
        }

        isLoading = false
    }
    
    func forceReload() async {
        DebugLogger.shared.log("forceReload 开始")
        coreDataStatus = CoreDataStack.shared.debugInfo
        
        debugStorePath = CoreDataStack.shared.storeURL?.path ?? ""

        do {
            let count = try await countBooks()
            let allBooks = try await fetchBooks(page: 0, size: pageSize)
            
            debugDiskBookCount = count
            books = allBooks
            hasMore = allBooks.count == pageSize
            
            DebugLogger.shared.log("forceReload 完成: UI=\(allBooks.count), 磁盘=\(count)")
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
            DebugLogger.shared.log("forceReload 失败: \(error)")
        }
    }

    var debugSummary: String {
        let status = coreDataStatus.isEmpty ? "" : "\(coreDataStatus) | "
        if debugStorePath.isEmpty {
            return "\(status)store=<none>, 磁盘书籍=\(debugDiskBookCount)"
        }
        let parts = debugStorePath.split(separator: "/")
        let tail = parts.suffix(3).joined(separator: "/")
        return "\(status).../\(tail), 磁盘=\(debugDiskBookCount), 内存=\(books.count)"
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

        let groupFilter = self.groupFilter
        let sortBy = self.sortBy

        return try await context.perform {
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

            return try context.fetch(request)
        }
    }

    private func countBooks() async throws -> Int {
        let context = CoreDataStack.shared.viewContext

        return try await context.perform {
            let request: NSFetchRequest<Book> = Book.fetchRequest()
            request.includesPendingChanges = false
            return try context.count(for: request)
        }
    }
    
    func refreshBooks() async {
        await loadBooks()
    }
    
    func removeBook(_ book: Book) {
        let bookId = book.bookId
        let bookName = book.name
        DebugLogger.shared.log("removeBook 开始: bookId=\(bookId), name=\(bookName)")
        
        Task { @MainActor in
            let context = CoreDataStack.shared.viewContext
            
            let request: NSFetchRequest<Book> = Book.fetchRequest()
            request.predicate = NSPredicate(format: "bookId == %@", bookId as CVarArg)
            request.fetchLimit = 1
            
            guard let bookToDelete = try? context.fetch(request).first else {
                DebugLogger.shared.log("removeBook: 找不到书籍")
                return
            }
            
            context.delete(bookToDelete)
            
            do {
                try context.save()
                DebugLogger.shared.log("removeBook 成功")
            } catch {
                DebugLogger.shared.log("removeBook 失败: \(error.localizedDescription)")
            }
        }
    }
    
    func updateGroup(for book: Book, group: Int32) {
        book.group = Int64(group)
        try? CoreDataStack.shared.save()
    }
}

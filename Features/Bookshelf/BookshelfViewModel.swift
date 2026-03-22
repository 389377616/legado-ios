import Foundation
import CoreData
import Combine

@MainActor
final class BookshelfViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var groups: [BookGroup] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingAddUrl = false
    
    @Published var viewMode: ViewMode = .grid
    @Published var sortMode: SortMode = .readTime
    @Published var showUnread = true
    @Published var showUpdateTime = true
    @Published var showFastScroller = false
    
    var totalBookCount: Int { books.count }
    
    private let pageSize = 50
    private var currentPage = 0
    
    enum ViewMode: Int, CaseIterable {
        case grid = 0
        case list = 1
    }
    
    enum SortMode: Int, CaseIterable {
        case readTime = 0
        case updateTime = 1
        case name = 2
        case author = 3
    }
    
    private var loadTask: Task<Void, Never>?
    
    deinit {
        loadTask?.cancel()
    }
    
    func loadBooks() async {
        guard !isLoading else { return }
        isLoading = true
        
        do {
            books = try await fetchBooks()
            groups = try await fetchGroups()
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func refreshBooks() async {
        await loadBooks()
    }
    
    private func fetchBooks() async throws -> [Book] {
        let context = CoreDataStack.shared.viewContext
        let sortMode = self.sortMode
        
        return try await context.perform {
            let request: NSFetchRequest<Book> = Book.fetchRequest()
            request.fetchLimit = self.pageSize
            request.returnsObjectsAsFaults = false
            
            switch sortMode {
            case .readTime:
                request.sortDescriptors = [NSSortDescriptor(key: "durChapterTime", ascending: false)]
            case .updateTime:
                request.sortDescriptors = [NSSortDescriptor(key: "lastCheckTime", ascending: false)]
            case .name:
                request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
            case .author:
                request.sortDescriptors = [NSSortDescriptor(key: "author", ascending: true)]
            }
            
            return try context.fetch(request)
        }
    }
    
    private func fetchGroups() async throws -> [BookGroup] {
        let context = CoreDataStack.shared.viewContext
        
        return try await context.perform {
            let request: NSFetchRequest<BookGroup> = BookGroup.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
            request.predicate = NSPredicate(format: "show == YES")
            return try context.fetch(request)
        }
    }
    
    func removeBook(_ book: Book) {
        let bookId = book.bookId
        Task { @MainActor in
            let context = CoreDataStack.shared.viewContext
            let request: NSFetchRequest<Book> = Book.fetchRequest()
            request.predicate = NSPredicate(format: "bookId == %@", bookId as CVarArg)
            request.fetchLimit = 1
            
            guard let bookToDelete = try? context.fetch(request).first else { return }
            context.delete(bookToDelete)
            try? context.save()
        }
    }
    
    func updateBook(_ book: Book) {
        Task { @MainActor in
            let context = CoreDataStack.shared.viewContext
            let request: NSFetchRequest<Book> = Book.fetchRequest()
            request.predicate = NSPredicate(format: "bookId == %@", book.bookId as CVarArg)
            request.fetchLimit = 1
            
            guard let bookToUpdate = try? context.fetch(request).first else { return }
            bookToUpdate.lastCheckTime = Date()
            try? context.save()
        }
    }
    
    func updateAllToc() {
        Task { @MainActor in
            for book in books {
                book.lastCheckTime = Date()
            }
            try? CoreDataStack.shared.save()
        }
    }
    
    func addBookByUrl(_ url: String) {
        guard !url.isEmpty else { return }
        Task { @MainActor in
            let context = CoreDataStack.shared.viewContext
            let book = Book.create(in: context)
            book.bookUrl = url
            book.name = URL(string: url)?.lastPathComponent ?? "未知书籍"
            book.type = 0
            try? context.save()
            await loadBooks()
        }
    }
}
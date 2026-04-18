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
    @Published var groupStyle: GroupStyle = .tabs // 分组样式：分组Tab vs 统一列表
    @Published var gridColumns: Int = 4 // 网格列数（3-6），安卓原版默认4列
    @Published var showUnread = true
    @Published var showUpdateTime = true
    @Published var showFastScroller = false
    
    var totalBookCount: Int { books.count }
    
    private let pageSize = 50
    private var currentPage = 0
    
    // 参考 Android BookshelfFragment1（分组Tab）和 BookshelfFragment2（统一列表）
    enum GroupStyle: Int, CaseIterable {
        case tabs = 0      // Fragment1: ViewPager + TabLayout，每个分组一个Tab
        case unified = 1   // Fragment2: 统一列表，分组作为分隔标题
    }
    
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
            bookToUpdate.lastCheckTime = Int64(Date().timeIntervalSince1970 * 1000)
            try? context.save()
        }
    }
    
    func updateAllToc() {
        Task { @MainActor in
            for book in books {
                book.lastCheckTime = Int64(Date().timeIntervalSince1970 * 1000)
            }
            try? CoreDataStack.shared.save()
        }
    }
    
    func addBookByUrl(_ url: String) {
        guard !url.isEmpty else { return }
        Task { @MainActor in
            let context = CoreDataStack.shared.viewContext
            
            let bookData = BookImportData(
                name: URL(string: url)?.lastPathComponent ?? "未知书籍",
                author: "",
                bookUrl: url,
                tocUrl: "",
                origin: "url",
                originName: "URL导入"
            )
            
            do {
                _ = try BookDeduplicator.importBook(bookData, context: context)
                try context.save()
                await loadBooks()
            } catch {
                errorMessage = "添加失败：\(error.localizedDescription)"
            }
        }
    }
}
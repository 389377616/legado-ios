import SwiftUI
import CoreData

struct BookDetailView: View {
    @StateObject private var viewModel: BookDetailViewModel
    @State private var showingChapterList = false
    @State private var showingSourceSelection = false
    @State private var navigatingToReader = false
    @Environment(\.dismiss) var dismiss
    
    let book: Book
    
    init(book: Book) {
        self.book = book
        _viewModel = StateObject(wrappedValue: BookDetailViewModel(book: book))
    }
    
    var body: some View {
        ZStack {
            backgroundView
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        arcHeaderView
                        infoSection
                    }
                }
                
                Divider()
                bottomActionBar
            }
        }
        .navigationTitle("书籍详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { viewModel.cacheAllChapters() }) {
                        Label("缓存全本", systemImage: "arrow.down.circle")
                    }
                    Button(action: { Task { await viewModel.refreshBookInfo() } }) {
                        Label("刷新书籍信息", systemImage: "arrow.clockwise")
                    }
                    Divider()
                    Button("从书架移除", role: .destructive) {
                        viewModel.deleteBook(book)
                        dismiss()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showingChapterList) {
            ChapterListView(viewModel: ReaderViewModel(), book: book)
        }
        .sheet(isPresented: $showingSourceSelection) {
            SourceSelectionSheet(book: book, selectedSource: $viewModel.currentSource)
        }
        .navigationDestination(isPresented: $navigatingToReader) {
            ReaderView(bookId: book.bookId)
        }
        .task { await viewModel.loadChapters() }
    }
    
    private var backgroundView: some View {
        Group {
            if let coverUrl = book.displayCoverUrl, !coverUrl.isEmpty {
                AsyncImage(url: URL(string: coverUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 30)
                            .overlay(Color.black.opacity(0.5))
                            .ignoresSafeArea()
                    default:
                        Color.primary.colorInvert()
                            .ignoresSafeArea()
                    }
                }
            } else {
                Color.primary.colorInvert()
                    .ignoresSafeArea()
            }
        }
    }
    
    private var arcHeaderView: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 16)
            
            BookCoverView(url: book.displayCoverUrl)
                .frame(width: 110, height: 160)
                .cornerRadius(5)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            
            Spacer().frame(height: 24)
        }
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            nameAndLabels
            infoRows
            introView
        }
        .background(Color.primary.colorInvert())
    }
    
    private var nameAndLabels: some View {
        VStack(spacing: 8) {
            Text(book.name)
                .font(.system(size: 18, weight: .medium))
                .lineLimit(1)
            
            if let kind = book.kind, !kind.isEmpty {
                HStack(spacing: 4) {
                    ForEach(kind.split(separator: ",").prefix(3), id: \.self) { tag in
                        Text(tag.trimmingCharacters(in: .whitespaces))
                            .font(.system(size: 11))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .cornerRadius(3)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
    
    private var infoRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            infoRow(icon: "person.fill", text: book.author) {
                EmptyView()
            }
            
            infoRow(icon: "globe", text: book.originName) {
                Button("换源") {
                    showingSourceSelection = true
                }
                .font(.system(size: 13))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(4)
            }
            
            infoRow(icon: "book.fill", text: book.latestChapterTitle ?? "暂无最新章节") {
                EmptyView()
            }
            
            infoRow(icon: "folder.fill", text: "分组 \(book.group)") {
                EmptyView()
            }
            
            infoRow(icon: "list.bullet", text: "共 \(book.totalChapterNum) 章") {
                Button("查看") {
                    showingChapterList = true
                }
                .font(.system(size: 13))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private func infoRow<Trailing: View>(icon: String, text: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 18)
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Spacer()
            
            trailing()
        }
        .padding(.vertical, 6)
    }
    
    private var introView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let intro = book.displayIntro, !intro.isEmpty {
                Text(intro)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(viewModel.isIntroExpanded ? nil : 4)
                    .lineSpacing(4)
                
                if intro.count > 100 {
                    Button(action: { viewModel.isIntroExpanded.toggle() }) {
                        Text(viewModel.isIntroExpanded ? "收起" : "展开")
                            .font(.system(size: 13))
                            .foregroundColor(.blue)
                            .padding(.top, 8)
                    }
                }
            }
        }
        .padding(16)
    }
    
    private var bottomActionBar: some View {
        HStack(spacing: 0) {
            Button(action: {
                viewModel.deleteBook(book)
                dismiss()
            }) {
                Text("移出书架")
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            
            Button(action: {
                if viewModel.startReading() {
                    navigatingToReader = true
                }
            }) {
                Text(book.readProgress > 0 ? "继续阅读" : "开始阅读")
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
            }
        }
        .background(Color.primary.colorInvert())
    }
}

@MainActor
class BookDetailViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isIntroExpanded = false
    @Published var currentSource: BookSource?
    @Published var previewChapters: [ChapterPreview] = []
    
    let book: Book
    private let context = CoreDataStack.shared.viewContext
    
    init(book: Book) {
        self.book = book
        self.currentSource = book.source
    }
    
    func loadChapters() async {
        let request: NSFetchRequest<BookChapter> = BookChapter.fetchRequest()
        request.predicate = NSPredicate(format: "bookId == %@", book.bookId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \BookChapter.index, ascending: true)]
        request.fetchLimit = 5
        
        do {
            let chapters = try context.fetch(request)
            previewChapters = chapters.map { ChapterPreview(
                id: $0.chapterId,
                index: Int($0.index),
                title: $0.title,
                isCached: $0.isCached
            )}
        } catch { }
    }
    
    @discardableResult
    func startReading() -> Bool {
        if book.durChapterIndex < 0 { book.durChapterIndex = 0 }
        if book.durChapterPos < 0 { book.durChapterPos = 0 }
        book.durChapterTime = Int64(Date().timeIntervalSince1970)
        do {
            try CoreDataStack.shared.save()
            return true
        } catch {
            context.rollback()
            return false
        }
    }
    
    func refreshBookInfo() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let source = try resolveSource()
            try await WebBook.getBookInfo(source: source, book: book)
            let chapterCount = try await refreshChapterList(source: source)
            book.totalChapterNum = Int32(chapterCount)
            try CoreDataStack.shared.save()
            await loadChapters()
        } catch { }
    }
    
    func cacheAllChapters() {
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                let source = try resolveSource()
                _ = try await refreshChapterList(source: source)
                let request = BookChapter.fetchRequest(byBookId: book.bookId)
                let chapters = try context.fetch(request)
                for chapter in chapters {
                    if !chapter.isCached {
                        let content = try await WebBook.getContent(source: source, book: book, chapter: chapter)
                        try cacheChapterToDisk(chapter: chapter, content: content)
                    }
                }
                try CoreDataStack.shared.save()
                await loadChapters()
            } catch { }
        }
    }
    
    private func resolveSource() throws -> BookSource {
        if let currentSource { return currentSource }
        guard let sourceUUID = UUID(uuidString: book.origin) else {
            throw NSError(domain: "BookDetailViewModel", code: 1, userInfo: nil)
        }
        let request: NSFetchRequest<BookSource> = BookSource.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "sourceId == %@", sourceUUID as CVarArg)
        if let source = try context.fetch(request).first {
            currentSource = source
            return source
        }
        throw NSError(domain: "BookDetailViewModel", code: 2, userInfo: nil)
    }
    
    private func refreshChapterList(source: BookSource) async throws -> Int {
        let webChapters = try await WebBook.getChapterList(source: source, book: book)
        let request = BookChapter.fetchRequest(byBookId: book.bookId)
        let existing = try context.fetch(request)
        var existingByUrl: [String: BookChapter] = [:]
        for chapter in existing where !chapter.chapterUrl.isEmpty {
            if existingByUrl[chapter.chapterUrl] == nil {
                existingByUrl[chapter.chapterUrl] = chapter
            }
        }
        for web in webChapters {
            let url = web.url
            guard !url.isEmpty else { continue }
            if let chapter = existingByUrl[url] {
                chapter.title = web.title
                chapter.index = Int32(web.index)
                chapter.isVIP = web.isVip
                if let updateTime = web.updateTime {
                    chapter.updateTime = updateTime
                }
            } else {
                let chapter = BookChapter.create(in: context, bookId: book.bookId, url: url, index: Int32(web.index), title: web.title)
                chapter.book = book
                chapter.sourceId = source.sourceId.uuidString
                chapter.isVIP = web.isVip
                if let updateTime = web.updateTime {
                    chapter.updateTime = updateTime
                }
            }
        }
        book.totalChapterNum = Int32(webChapters.count)
        try CoreDataStack.shared.save()
        return webChapters.count
    }
    
    private func cacheChapterToDisk(chapter: BookChapter, content: String) throws {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("chapters", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let fileName = "\(chapter.bookId.uuidString)_\(chapter.index).txt"
        try content.write(to: dir.appendingPathComponent(fileName), atomically: true, encoding: .utf8)
        chapter.isCached = true
        chapter.cachePath = fileName
    }
    
    func deleteBook(_ book: Book) {
        context.delete(book)
        try? CoreDataStack.shared.save()
    }
}

struct ChapterPreview: Identifiable {
    let id: UUID
    let index: Int
    let title: String
    let isCached: Bool
}

struct SourceSelectionSheet: View {
    let book: Book
    @Binding var selectedSource: BookSource?
    @Environment(\.dismiss) var dismiss
    @State private var sources: [BookSource] = []
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sources, id: \.sourceId) { source in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(source.bookSourceName)
                            Text(source.bookSourceGroup ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if source.sourceId == selectedSource?.sourceId {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedSource = source
                        dismiss()
                    }
                }
            }
            .navigationTitle("选择书源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .task { await loadSources() }
        }
    }
    
    private func loadSources() async {
        let request: NSFetchRequest<BookSource> = BookSource.fetchRequest()
        request.predicate = NSPredicate(format: "enabled == YES")
        do {
            sources = try CoreDataStack.shared.viewContext.fetch(request)
        } catch { }
    }
}

#Preview {
    NavigationView {
        BookDetailView(book: Book())
    }
}

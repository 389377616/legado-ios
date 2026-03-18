//
//  ReaderViewModel.swift
//  Legado-iOS
//
//  阅读器 ViewModel
//

import Foundation
import SwiftUI
import CoreData

@MainActor
class ReaderViewModel: ObservableObject {
    // MARK: - Published 属性
    @Published var chapterContent: String?
    @Published var currentChapter: BookChapter?
    @Published var currentChapterIndex: Int = 0
    @Published var totalChapters: Int = 0
    @Published var chapters: [BookChapter] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentBook: Book?
    @Published var durChapterPos: Int32 = 0
    @Published var theme: ReaderTheme = .light
    @Published var useReplaceRule: Bool = true
    
    // MARK: - 分页状态
    @Published var currentPageIndex: Int = 0 {
        didSet {
            if oldValue != currentPageIndex {
                updatePagingProgressIfNeeded()
            }
        }
    }
    @Published var totalPages: Int = 0
    
    // MARK: - 阅读设置
    @Published var fontSize: CGFloat = 18 {
        didSet {
            UserDefaults.standard.set(Double(fontSize), forKey: "reader.fontSize")
        }
    }
    @Published var lineSpacing: CGFloat = 8 {
        didSet {
            UserDefaults.standard.set(Double(lineSpacing), forKey: "reader.lineSpacing")
        }
    }
    @Published var pagePadding: EdgeInsets = EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16) {
        didSet {
            UserDefaults.standard.set(Double(pagePadding.leading), forKey: "reader.pageMargin")
        }
    }
    @Published var backgroundColor: Color = .white
    @Published var textColor: Color = .black
    
    // MARK: - 新增阅读设置
    @Published var paragraphSpacing: CGFloat = 12
    @Published var letterSpacing: CGFloat = 0
    
    // MARK: - 私有属性
    private var ruleEngine: RuleEngine = RuleEngine()
    private var loadTask: Task<Void, Never>?
    let cacheManager = ChapterCacheManager()

    init() {
        loadReaderPreferences()
    }

    private func loadReaderPreferences() {
        let defaults = UserDefaults.standard

        let storedFontSize = defaults.double(forKey: "reader.fontSize")
        if storedFontSize > 0 {
            fontSize = CGFloat(storedFontSize)
        }

        let storedLineSpacing = defaults.double(forKey: "reader.lineSpacing")
        if storedLineSpacing > 0 {
            lineSpacing = CGFloat(storedLineSpacing)
        }

        let storedMargin = defaults.double(forKey: "reader.pageMargin")
        if storedMargin > 0 {
            let margin = CGFloat(storedMargin)
            pagePadding = EdgeInsets(top: 20, leading: margin, bottom: 20, trailing: margin)
        }

        if let storedTheme = defaults.string(forKey: "reader.theme") {
            applyTheme(themeFromStorage(storedTheme))
        }
    }

    private func themeFromStorage(_ raw: String) -> ReaderTheme {
        switch raw {
        case "暗色":
            return .dark
        case "羊皮纸":
            return .sepia
        case "护眼":
            return .eyeProtection
        default:
            return .light
        }
    }
    
    // MARK: - 颜色主题
    enum ReaderTheme {
        case light
        case dark
        case sepia
        case eyeProtection
        
        var backgroundColor: Color {
            switch self {
            case .light: return Color.white
            case .dark: return Color.black
            case .sepia: return Color(red: 0.96, green: 0.91, blue: 0.83)
            case .eyeProtection: return Color(red: 0.75, green: 0.84, blue: 0.71)
            }
        }
        
        var textColor: Color {
            switch self {
            case .light: return Color.black
            case .dark: return Color.white
            case .sepia: return Color(red: 0.33, green: 0.28, blue: 0.22)
            case .eyeProtection: return Color.black
            }
        }
    }
    
    // MARK: - 加载书籍
    func loadBook(byId bookId: UUID) {
        loadTask?.cancel()
        isLoading = true
        DebugLogger.shared.log("ReaderViewModel.loadBook 开始: bookId=\(bookId)")

        loadTask = Task {
            do {
                try Task.checkCancellation()
                
                let context = CoreDataStack.shared.viewContext
                context.refreshAllObjects()
                
                let request: NSFetchRequest<Book> = Book.fetchRequest()
                request.predicate = NSPredicate(format: "bookId == %@", bookId as CVarArg)
                request.fetchLimit = 1
                
                guard let book = try context.fetch(request).first else {
                    DebugLogger.shared.log("ReaderViewModel: 书籍不存在 bookId=\(bookId)")
                    errorMessage = "书籍不存在"
                    isLoading = false
                    return
                }
                
                DebugLogger.shared.log("ReaderViewModel: 找到书籍 name=\(book.name), type=\(book.type), origin=\(book.origin)")
                
                currentBook = book

                applyReadConfig(book)

                // 加载目录
                try await loadChapters(book: book)
                
                // 加载当前章节
                let chapterIndex = Int(book.durChapterIndex)
                if chapterIndex < chapters.count {
                    currentChapterIndex = chapterIndex
                    durChapterPos = book.durChapterPos
                    let restorePage = max(0, Int(book.durChapterPos))
                    try await loadChapter(at: chapterIndex, restorePageIndex: restorePage)
                }
                
                isLoading = false
            } catch is CancellationError {
                DebugLogger.shared.log("ReaderViewModel: 加载被取消")
                isLoading = false
            } catch {
                DebugLogger.shared.log("ReaderViewModel: 加载失败 \(error.localizedDescription)")
                errorMessage = "加载失败：\(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    func loadBook(_ book: Book) {
        loadBook(byId: book.bookId)
    }
    
    // MARK: - 加载目录
    private func loadChapters(book: Book) async throws {
        DebugLogger.shared.log("loadChapters: bookId=\(book.bookId), name=\(book.name), totalChapterNum=\(book.totalChapterNum)")
        
        let request = BookChapter.fetchRequest(byBookId: book.bookId)
        
        let context = CoreDataStack.shared.viewContext
        context.refreshAllObjects()
        var chapters = try context.fetch(request)
        
        DebugLogger.shared.log("loadChapters: 从 CoreData 获取到 \(chapters.count) 章")

        if chapters.isEmpty, !book.isLocal {
            guard let sourceId = UUID(uuidString: book.origin) else {
                throw ReaderError.noSource
            }

            let sourceRequest: NSFetchRequest<BookSource> = BookSource.fetchRequest()
            sourceRequest.fetchLimit = 1
            sourceRequest.predicate = NSPredicate(format: "sourceId == %@", sourceId as CVarArg)
            guard let source = try context.fetch(sourceRequest).first else {
                throw ReaderError.noSource
            }

            let webChapters = try await WebBook.getChapterList(source: source, book: book)
            guard !webChapters.isEmpty else {
                throw ReaderError.noChapters
            }

            for web in webChapters {
                let chapter = BookChapter.create(
                    in: context,
                    bookId: book.bookId,
                    url: web.url,
                    index: Int32(web.index),
                    title: web.title
                )
                chapter.book = book
                chapter.sourceId = source.sourceId.uuidString
                chapter.isVIP = web.isVip
            }

            book.totalChapterNum = Int32(webChapters.count)
            try CoreDataStack.shared.save()

            chapters = try context.fetch(request)
        }

        self.chapters = chapters
        self.totalChapters = chapters.count

        if chapters.isEmpty {
            throw ReaderError.noChapters
        }
    }
    
    // MARK: - 加载章节
    func loadChapter(at index: Int, restorePageIndex: Int? = nil) async throws {
        guard index >= 0 && index < chapters.count else {
            throw ReaderError.invalidChapterIndex
        }
        
        isLoading = true
        currentChapterIndex = index
        currentChapter = chapters[index]
        if let restorePageIndex {
            currentPageIndex = max(0, restorePageIndex)
            durChapterPos = Int32(currentPageIndex)
        } else {
            currentPageIndex = 0
            durChapterPos = 0
        }
        
        do {
            DebugLogger.shared.log("loadChapter: index=\(index), chapterId=\(chapters[index].chapterId), isCached=\(chapters[index].isCached), cachePath=\(chapters[index].cachePath ?? "nil")")
            // 尝试从缓存加载
            if let cachedContent = try? await loadCachedChapter(chapters[index]) {
                DebugLogger.shared.log("loadChapter: 从缓存加载成功，长度=\(cachedContent.count)")
                chapterContent = applyReplaceRulesIfNeeded(cachedContent, chapter: chapters[index])
                isLoading = false
                return
            }
            
            DebugLogger.shared.log("loadChapter: 缓存未命中，尝试 fetchChapterContent")
            // 从网络加载
            let content = try await fetchChapterContent(chapters[index])
            chapterContent = applyReplaceRulesIfNeeded(content, chapter: chapters[index])
            
            // 缓存章节
            try await cacheChapter(chapters[index], content: content)
            
            isLoading = false
            
            // 预加载前后章节
            if let book = currentBook {
                cacheManager.preloadAroundChapter(
                    index: index,
                    chapters: chapters,
                    book: book
                )
            }
        } catch {
            errorMessage = "加载章节失败：\(error.localizedDescription)"
            isLoading = false
            throw error
        }
    }
    
    // MARK: - 章节导航
    func prevChapter() async {
        guard currentChapterIndex > 0 else { return }
        do {
            try await loadChapter(at: currentChapterIndex - 1)
            saveProgress()
        } catch {
            errorMessage = "加载章节失败：\(error.localizedDescription)"
        }
    }
    
    func nextChapter() async {
        guard currentChapterIndex < totalChapters - 1 else { return }
        do {
            try await loadChapter(at: currentChapterIndex + 1)
            saveProgress()
        } catch {
            errorMessage = "加载章节失败：\(error.localizedDescription)"
        }
    }
    
    func jumpToChapter(_ index: Int) {
        guard index >= 0 && index < totalChapters else { return }
        
        Task {
            try? await loadChapter(at: index)
            saveProgress()
        }
    }

    func loadChapter() async {
        do {
            try await loadChapter(at: currentChapterIndex)
        } catch {
            errorMessage = "加载章节失败：\(error.localizedDescription)"
        }
    }

    func loadChapterList() async {
        guard let book = currentBook else { return }
        do {
            try await loadChapters(book: book)
        } catch {
            errorMessage = "加载目录失败：\(error.localizedDescription)"
        }
    }
    
    // MARK: - 阅读配置
    func applyReadConfig(_ book: Book) {
        let config = book.readConfigObj

        seedGlobalPageAnimationIfNeeded(from: config)

        // 应用主题
        applyTheme(themeFromStorage(UserDefaults.standard.string(forKey: "reader.theme") ?? "亮色"))

        useReplaceRule = config.useReplaceRule
    }

    private func seedGlobalPageAnimationIfNeeded(from config: ReadConfig) {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "pageAnimation") == nil else {
            return
        }
        defaults.set(Self.pageAnimationRawValue(from: config.pageAnim), forKey: "pageAnimation")
    }

    private static func pageAnimationRawValue(from configValue: Int32) -> String {
        let animation = PageAnimation(rawValue: configValue) ?? .cover
        switch animation {
        case .cover:
            return PageAnimationType.cover.rawValue
        case .simulation:
            return PageAnimationType.simulation.rawValue
        case .slide:
            return PageAnimationType.slide.rawValue
        case .scroll:
            return PageAnimationType.scroll.rawValue
        }
    }
    
    func applyTheme(_ theme: ReaderTheme) {
        self.theme = theme
        backgroundColor = theme.backgroundColor
        textColor = theme.textColor

        UserDefaults.standard.set(storageThemeValue(theme), forKey: "reader.theme")
    }

    private func storageThemeValue(_ theme: ReaderTheme) -> String {
        switch theme {
        case .light:
            return "亮色"
        case .dark:
            return "暗色"
        case .sepia:
            return "羊皮纸"
        case .eyeProtection:
            return "护眼"
        }
    }

    private func applyReplaceRulesIfNeeded(_ text: String, chapter: BookChapter) -> String {
        guard let book = currentBook else { return text }
        if !useReplaceRule {
            return text
        }
        return ReplaceEngineEnhanced.shared.applyForReader(
            text: text,
            bookId: book.bookId,
            chapterId: chapter.chapterId,
            context: CoreDataStack.shared.viewContext
        )
    }

    func turnToNextPage() -> Bool {
        guard totalPages > 0 else { return false }
        guard currentPageIndex + 1 < totalPages else { return false }
        currentPageIndex += 1
        return true
    }

    func turnToPreviousPage() -> Bool {
        guard totalPages > 0 else { return false }
        guard currentPageIndex > 0 else { return false }
        currentPageIndex -= 1
        return true
    }

    private func updatePagingProgressIfNeeded() {
        let clamped = max(0, currentPageIndex)
        let newPos = Int32(clamped)
        if durChapterPos != newPos {
            durChapterPos = newPos
        }
        saveProgress()
    }

    func setTheme(_ theme: ReaderTheme) async {
        applyTheme(theme)
    }

    func setFontSize(_ size: CGFloat) async {
        let clamped = min(max(size, 8), 32)
        fontSize = clamped
    }
    
    // MARK: - 缓存管理
    private func loadCachedChapter(_ chapter: BookChapter) async throws -> String {
        DebugLogger.shared.log("loadCachedChapter: chapterId=\(chapter.chapterId), isCached=\(chapter.isCached), cachePath=\(chapter.cachePath ?? "nil")")
        // 从文件系统加载缓存的章节内容
        guard chapter.isCached, let cachePath = chapter.cachePath, !cachePath.isEmpty else {
            DebugLogger.shared.log("loadCachedChapter: 章节未缓存或 cachePath 为空")
            throw ReaderError.notCached
        }
        
        let cacheURL: URL
        if cachePath.hasPrefix("/") {
            cacheURL = URL(fileURLWithPath: cachePath)
        } else {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            cacheURL = documents.appendingPathComponent("chapters").appendingPathComponent(cachePath)
        }
        
        DebugLogger.shared.log("loadCachedChapter: 检查文件路径=\(cacheURL.path)")
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            DebugLogger.shared.log("loadCachedChapter: 文件不存在")
            throw ReaderError.notCached
        }
        
        let content = try String(contentsOf: cacheURL, encoding: .utf8)
        DebugLogger.shared.log("loadCachedChapter: 加载成功，长度=\(content.count)")
        return content
    }
    
    private func fetchChapterContent(_ chapter: BookChapter) async throws -> String {
        guard let book = currentBook else {
            throw ReaderError.noBook
        }
        
        // 本地书籍直接返回 TXT 切片内容
        if book.origin == "local" {
            return try await loadLocalChapterContent(chapter)
        }
        
        // 网络书籍：通过 WebBook 从书源获取
        guard let sourceId = UUID(uuidString: book.origin) else {
            throw ReaderError.noSource
        }
        
        // 查找对应书源
        let request: NSFetchRequest<BookSource> = BookSource.fetchRequest()
        request.predicate = NSPredicate(format: "sourceId == %@", sourceId as CVarArg)
        
        guard let source = try? CoreDataStack.shared.viewContext.fetch(request).first else {
            throw ReaderError.noSource
        }
        
        return try await WebBook.getContent(source: source, book: book, chapter: chapter)
    }
    
    /// 加载本地 TXT 书籍的章节内容
    private func loadLocalChapterContent(_ chapter: BookChapter) async throws -> String {
        guard let book = currentBook else { throw ReaderError.noBook }
        
        // EPUB：从缓存文件读取章节内容
        if book.type == 1 || book.bookUrl.lowercased().hasSuffix(".epub") {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let cacheFileName = "\(book.bookId.uuidString)_\(chapter.index).txt"
            let cacheURL = documents.appendingPathComponent("chapters").appendingPathComponent(cacheFileName)
            
            DebugLogger.shared.log("EPUB 读取: bookId=\(book.bookId), chapter=\(chapter.index), path=\(cacheURL.path)")
            DebugLogger.shared.log("文件存在: \(FileManager.default.fileExists(atPath: cacheURL.path))")
            
            let chapterDirPath = documents.appendingPathComponent("chapters").path
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: chapterDirPath) {
                DebugLogger.shared.log("chapters 目录文件数: \(contents.count), 前5个: \(contents.prefix(5).joined(separator: ", "))")
            } else {
                DebugLogger.shared.log("chapters 目录不存在或为空")
            }
            
            if FileManager.default.fileExists(atPath: cacheURL.path) {
                return try String(contentsOf: cacheURL, encoding: .utf8)
            }
            
            throw ReaderError.notCached
        }
        
        // TXT：按章节分割读取（原有逻辑）
        let fileURL = URL(fileURLWithPath: book.bookUrl)
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        
        // 使用与 LocalBookViewModel 相同的分章逻辑
        let chapterPatterns = [
            #"^第[零一二三四五六七八九十百千万0-9]+[章回卷节部篇]"#,
            #"^第[0-9]+章"#,
            #"^Chapter [0-9]+"#,
            #"^\s*第[0-9一二三四五六七八九十]+节"#
        ]
        
        var chapters: [(title: String, content: String)] = []
        var currentTitle: String?
        var currentContent = ""
        
        for line in content.components(separatedBy: .newlines) {
            var isChapterStart = false
            for pattern in chapterPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) {
                    let range = NSRange(line.startIndex..., in: line)
                    if regex.firstMatch(in: line, range: range) != nil {
                        isChapterStart = true
                        break
                    }
                }
            }
            
            if isChapterStart {
                if let title = currentTitle { chapters.append((title, currentContent)) }
                currentTitle = line.trimmingCharacters(in: .whitespaces)
                currentContent = ""
            } else {
                currentContent += line + "\n"
            }
        }
        if let title = currentTitle { chapters.append((title, currentContent)) }
        if chapters.isEmpty { return content }
        
        let idx = Int(chapter.index)
        guard idx >= 0 && idx < chapters.count else { throw ReaderError.notCached }
        return chapters[idx].content.trimmingCharacters(in: .whitespaces)
    }
    
    private func cacheChapter(_ chapter: BookChapter, content: String) async throws {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let chapterDir = documents.appendingPathComponent("chapters", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: chapterDir.path) {
            try FileManager.default.createDirectory(at: chapterDir, withIntermediateDirectories: true)
        }
        
        let fileName = "\(chapter.bookId.uuidString)_\(chapter.index).txt"
        let fileURL = chapterDir.appendingPathComponent(fileName)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        
        chapter.isCached = true
        chapter.cachePath = fileName
        try? CoreDataStack.shared.save()
    }
    
    // MARK: - 保存进度
    func saveProgress() {
        guard let book = currentBook else { return }
        
        book.durChapterIndex = Int32(currentChapterIndex)
        book.durChapterTime = Int64(Date().timeIntervalSince1970)
        book.durChapterPos = durChapterPos
        
        if let chapter = currentChapter {
            book.durChapterTitle = chapter.title
        }
        
        try? CoreDataStack.shared.save()
    }

    func saveReadingProgress() async {
        saveProgress()
    }
    
}

extension ReaderViewModel {
    var currentContent: String? {
        get { chapterContent }
        set { chapterContent = newValue }
    }

    var chapterList: [BookChapter] {
        chapters
    }
}

enum ReaderError: LocalizedError {
    case noChapters
    case invalidChapterIndex
    case notCached
    case networkFailure
    case noBook
    case noSource
    case parseFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noChapters: return "没有章节"
        case .invalidChapterIndex: return "无效的章节索引"
        case .notCached: return "章节未缓存"
        case .networkFailure: return "网络加载失败"
        case .noBook: return "未找到书籍"
        case .noSource: return "未找到书源"
        case .parseFailed(let reason): return "解析失败：\(reason)"
        }
    }
}
// MARK: - 设置视图
struct ReaderSettingsView: View {
    @ObservedObject var viewModel: ReaderViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("字体")) {
                    Stepper("字号：\(Int(viewModel.fontSize))", value: $viewModel.fontSize, in: 12...32, step: 1)
                }
                
                Section(header: Text("间距")) {
                    Stepper("行距：\(Int(viewModel.lineSpacing))", value: $viewModel.lineSpacing, in: 4...20, step: 1)
                }
                
                Section(header: Text("主题")) {
                    Button("亮色") {
                        viewModel.applyTheme(.light)
                    }
                    
                    Button("暗色") {
                        viewModel.applyTheme(.dark)
                    }
                    
                    Button("护眼") {
                        viewModel.applyTheme(.eyeProtection)
                    }
                    
                    Button("羊皮纸") {
                        viewModel.applyTheme(.sepia)
                    }
                }
            }
            .navigationTitle("阅读设置")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - 目录列表
struct ChapterListView: View {
    @ObservedObject var viewModel: ReaderViewModel
    let book: Book
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(viewModel.chapters.enumerated()), id: \.element.chapterId) { index, chapter in
                    Button(action: {
                        viewModel.jumpToChapter(index)
                        dismiss()
                    }) {
                        HStack {
                            Text("\(index + 1)")
                                .frame(width: 40)
                            
                            Text(chapter.title)
                                .lineLimit(2)
                            
                            Spacer()
                            
                            if index == viewModel.currentChapterIndex {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                            
                            if chapter.isCached {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .navigationTitle("目录")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

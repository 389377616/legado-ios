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
    
    // MARK: - 阅读设置
    @Published var fontSize: CGFloat = 18
    @Published var lineSpacing: CGFloat = 8
    @Published var pagePadding: EdgeInsets = EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16)
    @Published var backgroundColor: Color = .white
    @Published var textColor: Color = .black
    
    // MARK: - 私有属性
    private var ruleEngine: RuleEngine = RuleEngine()
    private var loadTask: Task<Void, Never>?
    
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
    func loadBook(_ book: Book) {
        loadTask?.cancel()
        currentBook = book
        isLoading = true

        loadTask = Task {
            do {
                try Task.checkCancellation()
                // 加载目录
                try await loadChapters(book: book)
                
                // 加载当前章节
                let chapterIndex = Int(book.durChapterIndex)
                if chapterIndex < chapters.count {
                    currentChapterIndex = chapterIndex
                    try await loadChapter(at: chapterIndex)
                }
                
                // 应用阅读配置
                applyReadConfig(book)
                
                isLoading = false
            } catch is CancellationError {
                isLoading = false
            } catch {
                errorMessage = "加载失败：\(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    // MARK: - 加载目录
    private func loadChapters(book: Book) async throws {
        let request = BookChapter.fetchRequest(byBookId: book.bookId)
        
        let chapters = try CoreDataStack.shared.viewContext.fetch(request)
        self.chapters = chapters
        self.totalChapters = chapters.count
        
        if chapters.isEmpty {
            // 如果本地没有目录，需要从书源获取
            // TODO: 实现从书源获取目录
            throw ReaderError.noChapters
        }
    }
    
    // MARK: - 加载章节
    func loadChapter(at index: Int) async throws {
        guard index >= 0 && index < chapters.count else {
            throw ReaderError.invalidChapterIndex
        }
        
        isLoading = true
        currentChapterIndex = index
        currentChapter = chapters[index]
        
        do {
            // 尝试从缓存加载
            if let cachedContent = try? await loadCachedChapter(chapters[index]) {
                chapterContent = cachedContent
                isLoading = false
                return
            }
            
            // 从网络加载
            let content = try await fetchChapterContent(chapters[index])
            chapterContent = content
            
            // 缓存章节
            try await cacheChapter(chapters[index], content: content)
            
            isLoading = false
        } catch {
            errorMessage = "加载章节失败：\(error.localizedDescription)"
            isLoading = false
            throw error
        }
    }
    
    // MARK: - 章节导航
    func prevChapter() {
        guard currentChapterIndex > 0 else { return }
        
        Task {
            try? await loadChapter(at: currentChapterIndex - 1)
            saveProgress()
        }
    }

    func prevChapter() async {
        guard currentChapterIndex > 0 else { return }
        do {
            try await loadChapter(at: currentChapterIndex - 1)
            saveProgress()
        } catch {
            errorMessage = "加载章节失败：\(error.localizedDescription)"
        }
    }
    
    func nextChapter() {
        guard currentChapterIndex < totalChapters - 1 else { return }
        
        Task {
            try? await loadChapter(at: currentChapterIndex + 1)
            saveProgress()
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
        
        // 应用翻页动画
        // TODO: 实现翻页动画
        
        // 应用主题
        applyTheme(.light)  // 默认亮色主题
        
        // 应用其他设置
        // TODO: 实现更多配置项
    }
    
    func applyTheme(_ theme: ReaderTheme) {
        self.theme = theme
        backgroundColor = theme.backgroundColor
        textColor = theme.textColor
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
        // TODO: 实现缓存加载
        throw ReaderError.notCached
    }
    
    private func fetchChapterContent(_ chapter: BookChapter) async throws -> String {
        // TODO: 实现从书源获取章节内容
        // 这里需要调用 RuleEngine 解析书源规则
        return "章节内容加载中..."
    }
    
    private func cacheChapter(_ chapter: BookChapter, content: String) async throws {
        // TODO: 实现章节缓存
        chapter.isCached = true
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
    
    func goBack() {
        saveProgress()
        // TODO: 返回书架
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

// MARK: - 错误类型
enum ReaderError: LocalizedError {
    case noChapters
    case invalidChapterIndex
    case notCached
    case networkFailure
    
    var errorDescription: String? {
        switch self {
        case .noChapters: return "没有章节"
        case .invalidChapterIndex: return "无效的章节索引"
        case .notCached: return "章节未缓存"
        case .networkFailure: return "网络加载失败"
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

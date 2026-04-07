//
//  ReadBook.swift
//  Legado
//
//  基于 Android Legado 原版 ReadBook.kt 移植
//  原版路径: app/src/main/java/io/legado/app/model/ReadBook.kt
//

import Foundation
import CoreData

protocol ReadBookCallBack: AnyObject {
    func upContent()
    func upMenuView()
    func upPageAnim()
}

class ReadBook: ObservableObject {
    static let shared = ReadBook()
    
    @Published var book: Book?
    weak var callBack: ReadBookCallBack?
    var inBookshelf = false
    
    var chapterSize: Int = 0
    var simulatedChapterSize: Int = 0
    @Published var durChapterIndex: Int = 0
    @Published var durChapterPos: Int = 0
    var isLocalBook = true
    var chapterChanged = false
    
    var prevTextChapter: TextChapter?
    var curTextChapter: TextChapter?
    var nextTextChapter: TextChapter?
    
    var bookSource: BookSource?
    
    var msg: String?
    
    private var loadingChapters: Set<Int> = []
    private var chapterLoadingTasks: [Int: Task<Void, Never>] = [:]
    
    var readStartTime: Date = Date()
    
    private init() {}
    
    func resetData(_ book: Book) {
        releaseAndCancel()
        self.book = book
        chapterSize = book.chapterSize
        simulatedChapterSize = chapterSize
        durChapterIndex = Int(book.durChapterIndex)
        durChapterPos = Int(book.durChapterPos)
        isLocalBook = book.isLocal
        clearTextChapter()
        callBack?.upContent()
        callBack?.upMenuView()
        callBack?.upPageAnim()
        upBookSource(book)
        loadingChapters.removeAll()
    }
    
    func upData(_ book: Book) {
        releaseAndCancel()
        self.book = book
        chapterSize = book.chapterSize
        simulatedChapterSize = chapterSize
        
        if durChapterIndex != Int(book.durChapterIndex) {
            durChapterIndex = Int(book.durChapterIndex)
            durChapterPos = Int(book.durChapterPos)
            clearTextChapter()
        }
        
        if curTextChapter?.isCompleted == false {
            curTextChapter = nil
        }
        if nextTextChapter?.isCompleted == false {
            nextTextChapter = nil
        }
        if prevTextChapter?.isCompleted == false {
            prevTextChapter = nil
        }
        
        callBack?.upMenuView()
        upBookSource(book)
        loadingChapters.removeAll()
    }
    
    private func upBookSource(_ book: Book) {
        if book.isLocal {
            bookSource = nil
        } else {
            bookSource = nil
        }
    }
    
    func clearTextChapter() {
        prevTextChapter = nil
        curTextChapter = nil
        nextTextChapter = nil
    }
    
    func releaseAndCancel() {
        for (_, task) in chapterLoadingTasks {
            task.cancel()
        }
        chapterLoadingTasks.removeAll()
        loadingChapters.removeAll()
    }
    
    func loadContent(resetPageOffset: Bool = true) {
        guard let book = book else { return }
        
        if resetPageOffset {
            durChapterPos = 0
        }
        
        Task { @MainActor in
            await loadCurrentChapter()
            await loadPrevChapter()
            await loadNextChapter()
            callBack?.upContent()
        }
    }
    
    private func loadCurrentChapter() async {
        guard let book = book, durChapterIndex >= 0 && durChapterIndex < chapterSize else { return }
        
        if loadingChapters.contains(durChapterIndex) { return }
        loadingChapters.insert(durChapterIndex)
        
        let task = Task {
            do {
                let textChapter = try await loadChapter(index: durChapterIndex, book: book)
                await MainActor.run {
                    self.curTextChapter = textChapter
                    self.loadingChapters.remove(durChapterIndex)
                }
            } catch {
                await MainActor.run {
                    self.msg = "加载失败: \(error.localizedDescription)"
                    self.loadingChapters.remove(durChapterIndex)
                }
            }
        }
        
        chapterLoadingTasks[durChapterIndex] = task
    }
    
    private func loadPrevChapter() async {
        guard let book = book, durChapterIndex > 0 else { return }
        let prevIndex = durChapterIndex - 1
        
        if loadingChapters.contains(prevIndex) { return }
        loadingChapters.insert(prevIndex)
        
        let task = Task {
            do {
                let textChapter = try await loadChapter(index: prevIndex, book: book)
                await MainActor.run {
                    self.prevTextChapter = textChapter
                    self.loadingChapters.remove(prevIndex)
                }
            } catch {
                await MainActor.run {
                    self.loadingChapters.remove(prevIndex)
                }
            }
        }
        
        chapterLoadingTasks[prevIndex] = task
    }
    
    private func loadNextChapter() async {
        guard let book = book, durChapterIndex < chapterSize - 1 else { return }
        let nextIndex = durChapterIndex + 1
        
        if loadingChapters.contains(nextIndex) { return }
        loadingChapters.insert(nextIndex)
        
        let task = Task {
            do {
                let textChapter = try await loadChapter(index: nextIndex, book: book)
                await MainActor.run {
                    self.nextTextChapter = textChapter
                    self.loadingChapters.remove(nextIndex)
                }
            } catch {
                await MainActor.run {
                    self.loadingChapters.remove(nextIndex)
                }
            }
        }
        
        chapterLoadingTasks[nextIndex] = task
    }
    
    private func loadChapter(index: Int, book: Book) async throws -> TextChapter {
        let context = CoreDataStack.shared.newBackgroundContext()
        
        let chapter: BookChapter = try await context.perform {
            let request: NSFetchRequest<BookChapter> = BookChapter.fetchRequest()
            request.predicate = NSPredicate(format: "book.bookUrl == %@ AND index == %d", book.bookUrl, index)
            request.fetchLimit = 1
            
            guard let chapter = try context.fetch(request).first else {
                throw NSError(domain: "ReadBook", code: 404, userInfo: [NSLocalizedDescriptionKey: "章节不存在"])
            }
            return chapter
        }
        
        let title = chapter.title
        let content = try await getChapterContent(chapter: chapter, book: book)
        
        let textChapter = TextChapter(
            chapter: chapter,
            position: index,
            title: title,
            chaptersSize: chapterSize,
            sameTitleRemoved: false,
            isVip: false,
            isPay: false,
            effectiveReplaceRules: nil
        )
        
        let bookContent = BookContent(textList: content)
        
        let layout = TextChapterLayout(
            textChapter: textChapter,
            textPages: [],
            book: book,
            bookContent: bookContent
        )
        
        await layout.startLayout()
        
        return textChapter
    }
    
    private func getChapterContent(chapter: BookChapter, book: Book) async throws -> [String] {
        if book.isLocal {
            return ["章节内容加载中..."]
        } else {
            return ["正在加载章节内容..."]
        }
    }
    
    func setPageIndex(_ index: Int) {
        durChapterPos = index
        callBack?.upContent()
    }
    
    func moveToNextChapter(_ upContent: Bool, _ upContentInPlace: Bool) {
        guard durChapterIndex < chapterSize - 1 else { return }
        durChapterIndex += 1
        durChapterPos = 0
        chapterChanged = true
        
        prevTextChapter = curTextChapter
        curTextChapter = nextTextChapter
        nextTextChapter = nil
        
        if upContent {
            loadContent(resetPageOffset: !upContentInPlace)
        }
        
        saveReadProgress()
    }
    
    func moveToPrevChapter(_ upContent: Bool, upContentInPlace: Bool) {
        guard durChapterIndex > 0 else { return }
        durChapterIndex -= 1
        durChapterPos = 0
        chapterChanged = true
        
        nextTextChapter = curTextChapter
        curTextChapter = prevTextChapter
        prevTextChapter = nil
        
        if upContent {
            loadContent(resetPageOffset: !upContentInPlace)
        }
        
        saveReadProgress()
    }
    
    func pageAnim() -> Int {
        return book?.pageAnim ?? 0
    }
    
    func saveReadProgress() {
        guard let book = book else { return }
        
        let context = CoreDataStack.shared.viewContext
        context.perform {
            book.durChapterIndex = Int32(self.durChapterIndex)
            book.durChapterPos = Int32(self.durChapterPos)
            book.durChapterTime = Int64(Date().timeIntervalSince1970)
            book.updatedAt = Date()
            
            do {
                try context.save()
            } catch {
                print("保存进度失败: \(error)")
            }
        }
    }
    
    var currentChapter: TextChapter? {
        return curTextChapter
    }
    
    var prevChapter: TextChapter? {
        return prevTextChapter
    }
    
    var nextChapter: TextChapter? {
        return nextTextChapter
    }
    
    func hasPrevChapter() -> Bool {
        return durChapterIndex > 0
    }
    
    func hasNextChapter() -> Bool {
        return durChapterIndex < chapterSize - 1
    }
}
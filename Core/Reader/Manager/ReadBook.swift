//
//  ReadBook.swift
//  Legado
//
//  基于 Android Legado 原版 ReadBook.kt 移植
//  原版路径: app/src/main/java/io/legado/app/model/ReadBook.kt
//

import Foundation

/// 回调协议
protocol ReadBookCallBack: AnyObject {
    func upContent()
    func upMenuView()
    func upPageAnim()
}

/// 阅读管理单例
/// 一比一移植自 Android Legado ReadBook
/// 管理阅读状态、章节加载、进度同步
class ReadBook: ObservableObject {
    static let shared = ReadBook()
    
    // MARK: - 书籍状态
    @Published var book: Book?
    weak var callBack: ReadBookCallBack?
    var inBookshelf = false
    
    // MARK: - 章节状态
    var chapterSize: Int = 0
    var simulatedChapterSize: Int = 0
    @Published var durChapterIndex: Int = 0
    @Published var durChapterPos: Int = 0
    var isLocalBook = true
    var chapterChanged = false
    
    // MARK: - TextChapter 缓存
    var prevTextChapter: TextChapter?
    var curTextChapter: TextChapter?
    var nextTextChapter: TextChapter?
    
    // MARK: - 书源
    var bookSource: BookSource?
    
    // MARK: - 消息
    var msg: String?
    
    // MARK: - 加载状态
    private var loadingChapters: Set<Int> = []
    
    // MARK: - 阅读时间
    var readStartTime: Date = Date()
    
    private init() {}
    
    // MARK: - 重置数据
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
    
    // MARK: - 更新数据
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
    
    // MARK: - 更新书源
    private func upBookSource(_ book: Book) {
        if book.isLocal {
            bookSource = nil
        } else {
            // TODO: 从数据库获取书源
            bookSource = nil
        }
    }
    
    // MARK: - 清理 TextChapter
    func clearTextChapter() {
        prevTextChapter = nil
        curTextChapter = nil
        nextTextChapter = nil
    }
    
    // MARK: - 释放资源
    func releaseAndCancel() {
        // TODO: 取消所有加载任务
    }
    
    // MARK: - 加载内容
    func loadContent(resetPageOffset: Bool = true) {
        // TODO: 实现章节加载逻辑
        callBack?.upContent()
    }
    
    // MARK: - 页面导航
    func setPageIndex(_ index: Int) {
        durChapterPos = index
        callBack?.upContent()
    }
    
    func moveToNextChapter(_ upContent: Bool, _ upContentInPlace: Bool) {
        guard durChapterIndex < chapterSize - 1 else { return }
        durChapterIndex += 1
        durChapterPos = 0
        chapterChanged = true
        clearTextChapter()
        if upContent {
            loadContent(resetPageOffset: !upContentInPlace)
        }
    }
    
    func moveToPrevChapter(_ upContent: Bool, upContentInPlace: Bool) {
        guard durChapterIndex > 0 else { return }
        durChapterIndex -= 1
        durChapterPos = 0
        chapterChanged = true
        clearTextChapter()
        if upContent {
            loadContent(resetPageOffset: !upContentInPlace)
        }
    }
    
    // MARK: - 获取页面动画类型
    func pageAnim() -> Int {
        return book?.pageAnim ?? 0
    }
    
    // MARK: - 保存进度
    func saveReadProgress() {
        guard let book = book else { return }
        // TODO: 保存阅读进度到数据库
    }
    
    // MARK: - 当前章节
    var currentChapter: TextChapter? {
        return curTextChapter
    }
    
    var prevChapter: TextChapter? {
        return prevTextChapter
    }
    
    var nextChapter: TextChapter? {
        return nextTextChapter
    }
    
    // MARK: - 检查章节
    func hasPrevChapter() -> Bool {
        return durChapterIndex > 0
    }
    
    func hasNextChapter() -> Bool {
        return durChapterIndex < chapterSize - 1
    }
}
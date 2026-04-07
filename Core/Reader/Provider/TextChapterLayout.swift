//
//  TextChapterLayout.swift
//  Legado
//
//  基于 Android Legado 原版 TextChapterLayout.kt 移植
//  原版路径: app/src/main/java/io/legado/app/ui/book/read/page/provider/TextChapterLayout.kt
//

import UIKit
import Foundation

/// 异步章节排版器
/// 一比一移植自 Android Legado TextChapterLayout
/// 使用 async/await + AsyncStream 实现异步排版
@MainActor
class TextChapterLayout {
    private weak var textChapter: TextChapter?
    private var textPages: [TextPage] = []
    private let book: Book
    private let bookContent: BookContent
    
    private var listener: LayoutProgressListener?
    
    private var durY: CGFloat = 0
    private var absStartX: CGFloat = 0
    private var pendingTextPage = TextPage()
    private var stringBuilder = StringBuilder()
    
    var exception: Error?
    var isCompleted = false
    
    private var pageStreamContinuation: AsyncStream<TextPage>.Continuation?
    var pageStream: AsyncStream<TextPage> {
        AsyncStream { continuation in
            self.pageStreamContinuation = continuation
        }
    }
    
    init(
        textChapter: TextChapter,
        textPages: [TextPage],
        book: Book,
        bookContent: BookContent
    ) {
        self.textChapter = textChapter
        self.textPages = textPages
        self.book = book
        self.bookContent = bookContent
    }
    
    func setProgressListener(_ listener: LayoutProgressListener?) {
        if isCompleted {
            return
        } else if exception != nil {
            listener?.onLayoutException(exception!)
        } else {
            self.listener = listener
        }
    }
    
    func cancel() {
        pageStreamContinuation?.finish()
        listener = nil
    }
    
    // MARK: - 开始排版
    func startLayout() async {
        do {
            try await layoutChapter()
        } catch {
            self.exception = error
            onException(error)
        }
    }
    
    private func layoutChapter() async throws {
        let provider = ChapterProvider.shared
        let contents = bookContent.textList
        
        let paddingLeft = provider.paddingLeft
        let paddingTop = provider.paddingTop
        let visibleWidth = provider.visibleWidth
        let visibleHeight = provider.visibleHeight
        
        absStartX = paddingLeft
        
        let titlePaintTextHeight = provider.titlePaintTextHeight
        let titlePaintFontMetrics = provider.titleFont
        
        let contentPaintTextHeight = provider.contentPaintTextHeight
        let contentPaintFontMetrics = provider.contentFont
        
        let titleBottomSpacing = provider.titleBottomSpacing
        let lineSpacingExtra = provider.lineSpacingExtra
        let paragraphSpacing = provider.paragraphSpacing
        
        // TODO: 实现完整的排版逻辑
        // 1. 处理标题
        // 2. 处理正文内容
        // 3. 处理图片
        
        let textPage = pendingTextPage
        let endPadding: CGFloat = 20
        let durYPadding = durY + endPadding
        
        if Float(textPage.height) < Float(durYPadding) {
            textPage.height = Float(durYPadding)
        } else {
            textPage.height += Float(endPadding)
        }
        
        textPage.text = stringBuilder.toString()
        
        onPageCompleted()
        onCompleted()
    }
    
    // MARK: - 页面完成回调
    private func onPageCompleted() {
        guard let textChapter = textChapter else { return }
        
        let textPage = pendingTextPage
        textPage.index = textPages.count
        textPage.chapterIndex = Int(textChapter.chapter.index)
        textPage.chapterSize = textChapter.chaptersSize
        textPage.title = textChapter.title
        textPage.doublePage = ChapterProvider.shared.doublePage
        textPage.paddingTop = ChapterProvider.shared.paddingTop
        textPage.isCompleted = true
        textPage.textChapter = textChapter
        textPage.upLinesPosition()
        textPage.upRenderHeight()
        
        textPages.append(textPage)
        pageStreamContinuation?.yield(textPage)
        
        listener?.onLayoutPageCompleted(textPages.count - 1, page: textPage)
    }
    
    private func onCompleted() {
        isCompleted = true
        pageStreamContinuation?.finish()
        listener?.onLayoutCompleted()
        listener = nil
    }
    
    private func onException(_ error: Error) {
        pageStreamContinuation?.finish()
        listener?.onLayoutException(error)
        listener = nil
    }
}

/// 书籍内容占位类型
/// TODO: 从 BookHelp 模块导入或创建完整实现
struct BookContent {
    var textList: [String] = []
    var sameTitleRemoved: Bool = false
    var effectiveReplaceRules: [ReplaceRule]? = nil
}
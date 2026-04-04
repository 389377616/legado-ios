//
//  WebBook.swift
//  Legado-iOS
//
//  网络书籍操作核心模块 - 参考原版 WebBook.kt
//  提供搜索、获取书籍信息、获取目录、获取正文的完整链路
//

import Foundation
import CoreData
import SwiftSoup

/// 搜索结果
struct SearchBookResult {
    var name: String = ""
    var author: String = ""
    var bookUrl: String = ""
    var coverUrl: String?
    var intro: String?
    var lastChapter: String?
    var wordCount: String?
    var sourceUrl: String = ""       // 来源书源 URL
    var sourceName: String = ""      // 来源书源名称
}

/// 章节信息（用于远程获取）
struct WebChapter {
    var title: String = ""
    var url: String = ""
    var index: Int = 0
    var isVip: Bool = false
    var updateTime: Int64?
}

/// WebBook 核心操作类
class WebBook {
    
    private static let ruleEngine = RuleEngine()
    private static let tocParser = TocParser(ruleEngine: ruleEngine)
    
    // MARK: - 搜索
    
    /// 在指定书源中搜索书籍
    static func searchBook(
        source: BookSource,
        key: String,
        page: Int = 1
    ) async throws -> [SearchBookResult] {
        guard let searchUrl = source.searchUrl, !searchUrl.isEmpty else {
            throw WebBookError.noSearchUrl
        }
        
        // 1. 构建搜索 URL
        let analyzedUrl = AnalyzeUrl.analyze(
            ruleUrl: searchUrl,
            key: key,
            page: page,
            baseUrl: source.bookSourceUrl,
            source: source
        )
        
        // 2. 发起请求
        let (body, redirectUrl) = try await AnalyzeUrl.getResponseBody(analyzedUrl: analyzedUrl)
        
        guard !body.isEmpty else {
            throw WebBookError.emptyResponse
        }
        
        // 3. 解析搜索结果
        guard let searchRule = source.getSearchRule() else {
            throw WebBookError.noRule("搜索规则")
        }
        
        return try parseBookList(
            source: source,
            body: body,
            baseUrl: redirectUrl,
            bookListRule: searchRule.bookList,
            nameRule: searchRule.name,
            authorRule: searchRule.author,
            bookUrlRule: searchRule.bookUrl,
            coverUrlRule: searchRule.coverUrl,
            introRule: searchRule.intro,
            lastChapterRule: searchRule.lastChapter,
            wordCountRule: searchRule.wordCount
        )
    }
    
    // MARK: - 获取书籍详情
    
    /// 获取书籍详细信息
    static func getBookInfo(
        source: BookSource,
        book: Book
    ) async throws {
        guard let infoRule = source.getBookInfoRule() else {
            throw WebBookError.noRule("书籍信息规则")
        }
        
        // 1. 请求详情页
        let analyzedUrl = AnalyzeUrl.analyze(
            ruleUrl: book.bookUrl,
            baseUrl: source.bookSourceUrl,
            source: source
        )
        let (body, redirectUrl) = try await AnalyzeUrl.getResponseBody(analyzedUrl: analyzedUrl)
        
        guard !body.isEmpty else {
            throw WebBookError.emptyResponse
        }
        
        // 2. 解析书籍信息
        let isJson = body.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") ||
                     body.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[")
        
        let context = ExecutionContext()
        if isJson {
            context.jsonString = body
        } else {
            context.document = try SwiftSoup.parse(body)
        }
        context.baseURL = URL(string: redirectUrl)
        
        let elementCtx = ElementContext(
            element: isJson ? (try JSONSerialization.jsonObject(with: body.data(using: .utf8)!) as Any) :
                     (try SwiftSoup.parse(body) as Any),
            baseUrl: redirectUrl
        )
        
        // 3. 填充书籍信息
        if let name = infoRule.name {
            let parsed = ruleEngine.getString(ruleStr: name, elementContext: elementCtx, baseUrl: redirectUrl)
            if !parsed.isEmpty { book.name = parsed }
        }
        if let author = infoRule.author {
            let parsed = ruleEngine.getString(ruleStr: author, elementContext: elementCtx, baseUrl: redirectUrl)
            if !parsed.isEmpty { book.author = parsed }
        }
        if let intro = infoRule.intro {
            let parsed = ruleEngine.getString(ruleStr: intro, elementContext: elementCtx, baseUrl: redirectUrl)
            if !parsed.isEmpty { book.intro = parsed }
        }
        if let coverUrl = infoRule.coverUrl {
            let parsed = ruleEngine.getString(ruleStr: coverUrl, elementContext: elementCtx, baseUrl: redirectUrl)
            if !parsed.isEmpty { book.coverUrl = parsed }
        }
        if let tocUrl = infoRule.tocUrl {
            let parsed = ruleEngine.getString(ruleStr: tocUrl, elementContext: elementCtx, baseUrl: redirectUrl)
            if !parsed.isEmpty { book.tocUrl = parsed }
        }
        if let lastChapter = infoRule.lastChapter {
            let parsed = ruleEngine.getString(ruleStr: lastChapter, elementContext: elementCtx, baseUrl: redirectUrl)
            if !parsed.isEmpty { book.latestChapterTitle = parsed }
        }
    }
    
    // MARK: - 获取目录
    
    /// 获取书籍章节目录
    static func getChapterList(
        source: BookSource,
        book: Book
    ) async throws -> [WebChapter] {
        guard let tocRule = source.getTocRule() else {
            throw WebBookError.noRule("目录规则")
        }
        
        let tocUrl = book.tocUrl.isEmpty ? book.bookUrl : book.tocUrl
        
        // 1. 请求目录页
        let analyzedUrl = AnalyzeUrl.analyze(
            ruleUrl: tocUrl,
            baseUrl: source.bookSourceUrl,
            source: source
        )
        let (body, redirectUrl) = try await AnalyzeUrl.getResponseBody(analyzedUrl: analyzedUrl)
        
        guard !body.isEmpty else {
            throw WebBookError.emptyResponse
        }

        var chapters = try tocParser.parseChapters(
            body: body,
            baseUrl: redirectUrl,
            rule: tocRule,
            startIndex: 0
        )

        var pageBody = body
        var pageUrl = redirectUrl
        var visitedUrls: Set<String> = [redirectUrl]

        while let nextUrl = tocParser.parseNextPageUrl(body: pageBody, baseUrl: pageUrl, rule: tocRule),
              !nextUrl.isEmpty,
              !visitedUrls.contains(nextUrl) {
            visitedUrls.insert(nextUrl)
            let nextAnalyzedUrl = AnalyzeUrl.analyze(
                ruleUrl: nextUrl,
                baseUrl: source.bookSourceUrl,
                source: source
            )
            let (nextBody, nextRedirectUrl) = try await AnalyzeUrl.getResponseBody(analyzedUrl: nextAnalyzedUrl)
            guard !nextBody.isEmpty else { break }

            visitedUrls.insert(nextRedirectUrl)
            let nextChapters = try tocParser.parseChapters(
                body: nextBody,
                baseUrl: nextRedirectUrl,
                rule: tocRule,
                startIndex: chapters.count
            )
            chapters.append(contentsOf: nextChapters)

            pageBody = nextBody
            pageUrl = nextRedirectUrl

            if visitedUrls.count >= 100 || chapters.count > 10000 {
                break
            }
        }

        return chapters
    }
    
    // MARK: - 获取正文
    
    /// 获取章节正文内容
    static func getContent(
        source: BookSource,
        book: Book,
        chapter: BookChapter
    ) async throws -> String {
        guard let contentRule = source.getContentRule() else {
            throw WebBookError.noRule("正文规则")
        }
        
        guard let ruleStr = contentRule.content, !ruleStr.isEmpty else {
            // 如果没有正文规则，直接返回章节 URL（可能就是内容本身）
            return chapter.chapterUrl
        }
        
        // 1. 请求正文页
        let analyzedUrl = AnalyzeUrl.analyze(
            ruleUrl: chapter.chapterUrl,
            baseUrl: source.bookSourceUrl,
            source: source
        )
        let (body, redirectUrl) = try await AnalyzeUrl.getResponseBody(analyzedUrl: analyzedUrl)
        
        guard !body.isEmpty else {
            throw WebBookError.emptyResponse
        }
        
        // 2. 解析正文
        let context = ExecutionContext()
        let isJson = body.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{")
        
        if isJson {
            context.jsonString = body
        } else {
            context.document = try SwiftSoup.parse(body)
        }
        context.baseURL = URL(string: redirectUrl)
        
        let elementCtx = ElementContext(
            element: isJson ? (try JSONSerialization.jsonObject(with: body.data(using: .utf8)!) as Any) :
                     (try SwiftSoup.parse(body) as Any),
            baseUrl: redirectUrl
        )
        
        var content = ruleEngine.getString(ruleStr: ruleStr, elementContext: elementCtx, baseUrl: redirectUrl)
        
        // 3. 处理正文分页（nextContentUrl）
        if let nextContentUrlRule = contentRule.nextContentUrl, !nextContentUrlRule.isEmpty {
            var nextBody = body
            var nextRedirectUrl = redirectUrl
            
            for _ in 0..<50 {  // 最多 50 页
                let nextElementCtx = ElementContext(
                    element: try SwiftSoup.parse(nextBody),
                    baseUrl: nextRedirectUrl
                )
                let nextUrl = ruleEngine.getString(ruleStr: nextContentUrlRule, elementContext: nextElementCtx, baseUrl: nextRedirectUrl)
                
                guard !nextUrl.isEmpty, nextUrl != nextRedirectUrl else { break }
                
                let nextAnalyzedUrl = AnalyzeUrl.analyze(
                    ruleUrl: nextUrl,
                    baseUrl: source.bookSourceUrl,
                    source: source
                )
                let result = try await AnalyzeUrl.getResponseBody(analyzedUrl: nextAnalyzedUrl)
                nextBody = result.body
                nextRedirectUrl = result.url
                
                let nextElementCtxInner = ElementContext(
                    element: try SwiftSoup.parse(nextBody),
                    baseUrl: nextRedirectUrl
                )
                let nextContent = ruleEngine.getString(ruleStr: ruleStr, elementContext: nextElementCtxInner, baseUrl: nextRedirectUrl)
                
                if !nextContent.isEmpty {
                    content += "\n" + nextContent
                }
            }
        }
        
        // 4. 应用替换规则（净化）
        if let replaceRegex = contentRule.replaceRegex, !replaceRegex.isEmpty {
            content = applyReplaceRegex(content, regex: replaceRegex)
        }
        
        return content
    }
    
    // MARK: - 解析书籍列表
    
    /// 从 HTML/JSON 中解析书籍列表（搜索结果/发现列表通用）
    private static func parseBookList(
        source: BookSource,
        body: String,
        baseUrl: String,
        bookListRule: String?,
        nameRule: String?,
        authorRule: String?,
        bookUrlRule: String?,
        coverUrlRule: String?,
        introRule: String?,
        lastChapterRule: String?,
        wordCountRule: String?
    ) throws -> [SearchBookResult] {
        let elements = try ruleEngine.getElements(
            ruleStr: bookListRule,
            body: body,
            baseUrl: baseUrl
        )
        
        var books: [SearchBookResult] = []
        
        for elementCtx in elements {
            var book = SearchBookResult()
            book.sourceUrl = source.bookSourceUrl
            book.sourceName = source.bookSourceName
            
            book.name = ruleEngine.getString(ruleStr: nameRule, elementContext: elementCtx, baseUrl: baseUrl)
            book.author = ruleEngine.getString(ruleStr: authorRule, elementContext: elementCtx, baseUrl: baseUrl)
            book.bookUrl = ruleEngine.getString(ruleStr: bookUrlRule, elementContext: elementCtx, baseUrl: baseUrl)
            book.coverUrl = ruleEngine.getString(ruleStr: coverUrlRule, elementContext: elementCtx, baseUrl: baseUrl)
            book.intro = ruleEngine.getString(ruleStr: introRule, elementContext: elementCtx, baseUrl: baseUrl)
            book.lastChapter = ruleEngine.getString(ruleStr: lastChapterRule, elementContext: elementCtx, baseUrl: baseUrl)
            book.wordCount = ruleEngine.getString(ruleStr: wordCountRule, elementContext: elementCtx, baseUrl: baseUrl)
            
            // 过滤无效结果
            if !book.name.isEmpty && !book.bookUrl.isEmpty {
                books.append(book)
            }
        }
        
        return books
    }
    
    // MARK: - 替换正则
    
    private static func applyReplaceRegex(_ content: String, regex: String) -> String {
        var result = content
        
        // 支持 "pattern##replacement" 格式
        let parts = regex.components(separatedBy: "##")
        if parts.count >= 2 {
            let pattern = parts[0]
            let replacement = parts[1]
            if let reg = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(result.startIndex..., in: result)
                result = reg.stringByReplacingMatches(in: result, range: range, withTemplate: replacement)
            }
        } else if let reg = try? NSRegularExpression(pattern: regex) {
            let range = NSRange(result.startIndex..., in: result)
            result = reg.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        
        return result
    }
}

// MARK: - 错误类型
enum WebBookError: LocalizedError {
    case noSearchUrl
    case noRule(String)
    case emptyResponse
    case parseFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noSearchUrl: return "书源未配置搜索 URL"
        case .noRule(let name): return "书源未配置\(name)"
        case .emptyResponse: return "服务器响应为空"
        case .parseFailed(let msg): return "解析失败：\(msg)"
        }
    }
}

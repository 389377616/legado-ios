//
//  AnalyzeUrl.swift
//  Legado-iOS
//
//  URL 解析与构建器 - 参考原版 AnalyzeUrl.kt
//  支持 {{key}}、{{page}} 变量替换、POST body 解析、headers 解析
//

import Foundation
import JavaScriptCore
import WebKit

/// URL 解析结果
struct AnalyzedUrl {
    var url: String
    var method: HTTPMethod = .get
    var body: String?
    var headers: [String: String] = [:]
    var charset: String?
    var webView: Bool = false
    var webJs: String?
    var sourceRegex: String?
    
    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
    }
}

/// URL 构建器 - 将书源中的规则 URL 解析为实际可用的请求
class AnalyzeUrl {
    
    /// 解析搜索/发现 URL
    /// - Parameters:
    ///   - ruleUrl: 规则 URL，如 "https://example.com/search?q={{key}}&page={{page}},{"method":"POST"}"
    ///   - key: 搜索关键词
    ///   - page: 页码
    ///   - baseUrl: 书源 URL（用于解析相对路径）
    ///   - source: 书源（用于获取 headers 等配置）
    /// - Returns: 解析后的 URL 结构
    static func analyze(
        ruleUrl: String,
        key: String? = nil,
        page: Int = 1,
        baseUrl: String? = nil,
        source: BookSource? = nil
    ) -> AnalyzedUrl {
        var result = AnalyzedUrl(url: "")
        let templateContext = buildTemplateContext(key: key, page: page, source: source)
        if let baseUrl {
            templateContext.baseURL = URL(string: baseUrl)
        }
        let preprocessedRuleUrl = preprocessRuleUrl(ruleUrl, context: templateContext)
        
        // 1. 分离 URL 和配置 JSON
        var urlPart = preprocessedRuleUrl
        var configJson: [String: Any]?
        
        // 检查是否有 JSON 配置（以 , + { 分隔）
        if let jsonConfig = findJsonConfig(in: preprocessedRuleUrl) {
            urlPart = String(preprocessedRuleUrl[..<jsonConfig.separator])
            let jsonStr = String(preprocessedRuleUrl[jsonConfig.jsonStart...])
            if let data = jsonStr.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                configJson = json
            }
        }
        
        // 2. 变量替换
        urlPart = replaceVariables(urlPart, context: templateContext)
        
        // 3. 解析 HTTP 方法
        if let method = configJson?["method"] as? String {
            result.method = method.uppercased() == "POST" ? .post : .get
        }
        
        // 4. 解析 POST body
        if let body = configJson?["body"] as? String {
            result.body = replaceVariables(body, context: templateContext)
        }
        
        // 5. 解析 headers
        if let headers = configJson?["headers"] as? [String: String] {
            result.headers = headers.mapValues { replaceVariables($0, context: templateContext) }
        }
        
        // 6. 解析编码
        if let charset = configJson?["charset"] as? String {
            result.charset = charset
        }
        
        // 7. 是否需要 WebView
        if let webView = configJson?["webView"] as? Bool {
            result.webView = webView
        }

        if let webJs = configJson?["webJs"] as? String,
           !webJs.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.webJs = webJs
        }

        if let sourceRegex = configJson?["sourceRegex"] as? String,
           !sourceRegex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.sourceRegex = sourceRegex
        }

        let optionJs = configJson?["js"] as? String
        
        // 8. 处理 URL 中的 POST 参数（用 , 分隔的旧格式）
        if result.method == .get && urlPart.contains(",{") == false {
            // 检查是否是 URL,body 的旧格式
            let parts = urlPart.split(separator: "\n", maxSplits: 1)
            if parts.count == 2 {
                urlPart = String(parts[0])
                result.body = replaceVariables(String(parts[1]), context: templateContext)
                result.method = .post
            }
        }
        
        // 9. 处理相对 URL
        if !urlPart.hasPrefix("http"), let base = baseUrl {
            if let resolved = URL(string: urlPart, relativeTo: URL(string: base))?.absoluteURL.absoluteString {
                urlPart = resolved
            }
        }

        if let optionJs,
           !optionJs.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let evaluatedURL = evaluateURLJavaScript(optionJs, context: templateContext, currentResult: urlPart),
           !evaluatedURL.isEmpty {
            urlPart = evaluatedURL
            if !urlPart.hasPrefix("http"), let base = baseUrl,
               let resolved = URL(string: urlPart, relativeTo: URL(string: base))?.absoluteURL.absoluteString {
                urlPart = resolved
            }
        }
        
        // 10. 合并书源 headers
        if let source = source, let headerStr = source.header,
           let data = headerStr.data(using: .utf8),
           let sourceHeaders = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            for (key, value) in sourceHeaders where result.headers[key] == nil {
                result.headers[key] = replaceVariables(value, context: templateContext)
            }
        }
        
        // 11. 添加默认 User-Agent
        if result.headers["User-Agent"] == nil {
            result.headers["User-Agent"] = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5 Mobile/15E148 Safari/604.1"
        }
        
        result.url = urlPart
        return result
    }
    
    // MARK: - 变量替换
    
    /// 替换 URL 中的变量占位符
    private static func replaceVariables(_ input: String, context: ExecutionContext) -> String {
        TemplateEngine.render(input, context: context)
    }

    private static func buildTemplateContext(key: String?, page: Int, source: BookSource?) -> ExecutionContext {
        let context = ExecutionContext()
        context.source = source
        if let source {
            context.baseURL = URL(string: source.bookSourceUrl)
        }

        if let key {
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            context.variables["key"] = encodedKey
            context.variables["searchKey"] = encodedKey
        }

        context.variables["page"] = "\(page)"
        context.variables["page-1"] = "\(page - 1)"

        if let variable = source?.variable,
           let data = variable.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for (name, value) in json {
                if let string = value as? String {
                    context.variables[name] = string
                } else if let bool = value as? Bool {
                    context.variables[name] = bool ? "true" : "false"
                } else if let number = value as? NSNumber {
                    context.variables[name] = number.stringValue
                }
            }
        }

        return context
    }

    private static func preprocessRuleUrl(_ ruleUrl: String, context: ExecutionContext) -> String {
        var working = ruleUrl

        if working.contains("<js>") && working.contains("</js>") {
            let analyzer = RuleAnalyzer(data: working, code: true)
            let replaced = analyzer.innerRule(startStr: "<js>", endStr: "</js>") { jsCode in
                evaluateURLJavaScript(jsCode, context: context, currentResult: working) ?? ""
            }
            if !replaced.isEmpty {
                working = replaced
            }
        }

        let trimmed = working.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("@js:") {
            let jsCode = String(trimmed.dropFirst(4))
            if let evaluated = evaluateURLJavaScript(jsCode, context: context, currentResult: working), !evaluated.isEmpty {
                working = evaluated
            }
        }

        if working.contains("{{") && working.contains("}}") {
            let resolved = RuleAnalyzer.resolveInnerRules(working) { token in
                if shouldKeepAsTemplateToken(token) {
                    return "{{\(token)}}"
                }
                let normalizedToken = normalizeInlineJSToken(token)
                return evaluateURLJavaScript(normalizedToken, context: context, currentResult: working) ?? ""
            }
            working = resolved
        }

        return replaceVariables(working, context: context)
    }

    private static func shouldKeepAsTemplateToken(_ token: String) -> Bool {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let lowercased = trimmed.lowercased()
        if lowercased.hasPrefix("js ") || lowercased.hasPrefix("js:") {
            return false
        }

        let jsIndicators = ["(", ")", "+", "-", "*", "/", "%", "?", ":", "=", "!", "&", "|", ";", "'", "\"", "java.", "cookie.", "source."]
        return !jsIndicators.contains(where: { trimmed.contains($0) })
    }

    private static func normalizeInlineJSToken(_ token: String) -> String {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()

        if lowercased.hasPrefix("js ") {
            return String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if lowercased.hasPrefix("js:") {
            return String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return trimmed
    }

    private static func evaluateURLJavaScript(_ jsCode: String, context: ExecutionContext, currentResult: String?) -> String? {
        let trimmed = jsCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return currentResult }

        let jsContext = context.jsContext
        for (key, value) in context.variables {
            if let intValue = Int(value) {
                jsContext.setValue(intValue, forKey: key)
            } else if let doubleValue = Double(value) {
                jsContext.setValue(doubleValue, forKey: key)
            } else if value == "true" || value == "false" {
                jsContext.setValue(value == "true", forKey: key)
            } else {
                jsContext.setValue(value, forKey: key)
            }
        }

        jsContext.setValue(currentResult, forKey: "result")
        jsContext.setValue(currentResult, forKey: "url")
        jsContext.setValue(context.baseURL?.absoluteString, forKey: "baseUrl")

        guard let value = jsContext.evaluateScript(trimmed) else {
            return currentResult
        }

        if let string = value.toString(), !string.isEmpty, string != "undefined", string != "null" {
            return string
        }

        return currentResult
    }
    
    // MARK: - JSON 配置查找
    
    /// 在 URL 字符串中查找 JSON 配置的起始位置
    private static func findJsonConfig(in url: String) -> (separator: String.Index, jsonStart: String.Index)? {
        var braceDepth = 0
        var bracketDepth = 0
        var inSingleQuote = false
        var inDoubleQuote = false
        var escaping = false
        var index = url.startIndex

        while index < url.endIndex {
            let char = url[index]

            if escaping {
                escaping = false
                index = url.index(after: index)
                continue
            }

            if char == "\\" {
                escaping = true
                index = url.index(after: index)
                continue
            }

            if char == "\"", !inSingleQuote {
                inDoubleQuote.toggle()
                index = url.index(after: index)
                continue
            }

            if char == "'", !inDoubleQuote {
                inSingleQuote.toggle()
                index = url.index(after: index)
                continue
            }

            if !inSingleQuote && !inDoubleQuote {
                switch char {
                case "{": braceDepth += 1
                case "}": braceDepth = max(0, braceDepth - 1)
                case "[": bracketDepth += 1
                case "]": bracketDepth = max(0, bracketDepth - 1)
                case ",":
                    let separatorIndex = index
                    var nextIndex = url.index(after: index)
                    while nextIndex < url.endIndex,
                          url[nextIndex].isWhitespace {
                        nextIndex = url.index(after: nextIndex)
                    }
                    if braceDepth == 0,
                       bracketDepth == 0,
                       nextIndex < url.endIndex,
                       url[nextIndex] == "{" {
                        return (separator: separatorIndex, jsonStart: nextIndex)
                    }
                default:
                    break
                }
            }

            index = url.index(after: index)
        }

        return nil
    }
    
    // MARK: - 发起请求
    
    /// 使用解析后的 URL 发起网络请求并返回响应内容
    static func getResponseBody(
        analyzedUrl: AnalyzedUrl,
        charset: String.Encoding = .utf8,
        javaScript: String? = nil,
        sourceRegex: String? = nil,
        forceWebView: Bool = false
    ) async throws -> (body: String, url: String) {
        guard let url = URL(string: analyzedUrl.url) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = analyzedUrl.method.rawValue
        request.timeoutInterval = 30
        
        // 设置 headers
        for (key, value) in analyzedUrl.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // 设置 body
        if let body = analyzedUrl.body {
            request.httpBody = body.data(using: .utf8)
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            }
        }

        let effectiveJavaScript = analyzedUrl.webJs ?? javaScript
        let effectiveSourceRegex = analyzedUrl.sourceRegex ?? sourceRegex

        if analyzedUrl.webView ||
            forceWebView ||
            !(effectiveJavaScript?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) ||
            !(effectiveSourceRegex?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            let fetcher = await WebViewHTMLFetcher()
            let result = try await fetcher.fetchHTML(
                request: request,
                timeout: request.timeoutInterval,
                javaScript: effectiveJavaScript,
                sourceRegex: effectiveSourceRegex
            )
            return (result.html, result.finalURL)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 处理编码
        let encoding = detectEncoding(data: data, response: response, charset: analyzedUrl.charset)
        let body = String(data: data, encoding: encoding) ?? String(data: data, encoding: .utf8) ?? ""
        
        let finalUrl = (response as? HTTPURLResponse)?.url?.absoluteString ?? analyzedUrl.url
        
        return (body, finalUrl)
    }
    
    // MARK: - 编码检测
    
    /// 自动检测响应内容的编码
    private static func detectEncoding(data: Data, response: URLResponse, charset: String?) -> String.Encoding {
        // 1. 优先使用书源指定的编码
        if let charset = charset {
            switch charset.lowercased() {
            case "gbk", "gb2312", "gb18030":
                return String.Encoding(
                    rawValue: CFStringConvertEncodingToNSStringEncoding(
                        CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
                    )
                )
            case "big5":
                return String.Encoding(
                    rawValue: CFStringConvertEncodingToNSStringEncoding(
                        CFStringEncoding(CFStringEncodings.big5.rawValue)
                    )
                )
            default:
                break
            }
        }
        
        // 2. 从 HTTP 响应头检测
        if let httpResponse = response as? HTTPURLResponse,
           let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") {
            if contentType.lowercased().contains("gbk") || contentType.lowercased().contains("gb2312") {
                return String.Encoding(
                    rawValue: CFStringConvertEncodingToNSStringEncoding(
                        CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
                    )
                )
            }
        }
        
        // 3. 从 HTML meta 标签检测
        if data.count > 0 {
            let prefix = String(data: data.prefix(1024), encoding: .ascii) ?? ""
            if prefix.lowercased().contains("charset=gbk") ||
               prefix.lowercased().contains("charset=gb2312") {
                return String.Encoding(
                    rawValue: CFStringConvertEncodingToNSStringEncoding(
                        CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
                    )
                )
            }
        }
        
        // 4. 默认 UTF-8
        return .utf8
    }
}

@MainActor
private final class WebViewHTMLFetcher: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<(html: String, finalURL: String), Error>?
    private var webView: WKWebView?
    private var timeoutTask: Task<Void, Never>?
    private var requestedURL: URL?
    private var extractionJavaScript: String?
    private var sourceRegex: String?

    func fetchHTML(
        request: URLRequest,
        timeout: TimeInterval,
        javaScript: String? = nil,
        sourceRegex: String? = nil
    ) async throws -> (html: String, finalURL: String) {
        if continuation != nil {
            throw WebViewFetchError.invalidState
        }

        requestedURL = request.url
        extractionJavaScript = javaScript?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceRegex = sourceRegex?.trimmingCharacters(in: .whitespacesAndNewlines)

        return try await withCheckedThrowingContinuation { cont in
            continuation = cont

            let config = WKWebViewConfiguration()
            config.websiteDataStore = .default()

            let webView = WKWebView(frame: .zero, configuration: config)
            self.webView = webView
            webView.navigationDelegate = self
            webView.load(request)

            timeoutTask = Task { [weak self] in
                let nanos = UInt64(max(1.0, timeout) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)
                await MainActor.run {
                    self?.finish(.failure(WebViewFetchError.timeout))
                }
            }
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 150_000_000)
            } catch {
            }

            await evaluateCompletedPage(on: webView)
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            finish(.failure(error))
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            finish(.failure(error))
        }
    }

    private func finish(_ result: Result<(html: String, finalURL: String), Error>) {
        guard let continuation else { return }
        self.continuation = nil

        timeoutTask?.cancel()
        timeoutTask = nil

        webView?.navigationDelegate = nil
        webView = nil
        requestedURL = nil
        extractionJavaScript = nil
        sourceRegex = nil

        switch result {
        case .success(let value):
            continuation.resume(returning: value)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    private func evaluateCompletedPage(on webView: WKWebView) async {
        let finalURL = webView.url?.absoluteString ?? requestedURL?.absoluteString ?? ""

        do {
            if let sourceRegex, !sourceRegex.isEmpty {
                if let script = extractionJavaScript, !script.isEmpty {
                    _ = try await evaluateJavaScript(script, on: webView)
                    try? await Task.sleep(nanoseconds: 300_000_000)
                }

                let resourcePayload = try await evaluateJavaScript(Self.resourceSnifferScript, on: webView)
                let resourceURLs = Self.decodeResourceURLs(resourcePayload)
                if let matched = Self.firstMatchingResource(in: resourceURLs, regex: sourceRegex) {
                    finish(.success((html: matched, finalURL: finalURL)))
                    return
                }
            }

            let script = (extractionJavaScript?.isEmpty == false) ? extractionJavaScript! : "document.documentElement.outerHTML"
            let result = try await evaluateJavaScript(script, on: webView)
            guard let stringResult = Self.stringifyJavaScriptResult(result), !stringResult.isEmpty else {
                finish(.failure(WebViewFetchError.noHTML))
                return
            }
            finish(.success((html: stringResult, finalURL: finalURL)))
        } catch {
            finish(.failure(error))
        }
    }

    private func evaluateJavaScript(_ script: String, on webView: WKWebView) async throws -> Any? {
        return try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result)
                }
            }
        }
    }

    private static func stringifyJavaScriptResult(_ result: Any?) -> String? {
        if let string = result as? String {
            return string
        }
        if let number = result as? NSNumber {
            return number.stringValue
        }
        if JSONSerialization.isValidJSONObject(result as Any),
           let data = try? JSONSerialization.data(withJSONObject: result as Any),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return nil
    }

    private static func decodeResourceURLs(_ result: Any?) -> [String] {
        if let string = result as? String,
           let data = string.data(using: .utf8),
           let array = try? JSONSerialization.jsonObject(with: data) as? [String] {
            return array
        }
        if let array = result as? [String] {
            return array
        }
        return []
    }

    private static func firstMatchingResource(in urls: [String], regex: String) -> String? {
        guard let pattern = try? NSRegularExpression(pattern: regex) else {
            return urls.first { $0.contains(regex) }
        }

        for url in urls {
            let range = NSRange(url.startIndex..., in: url)
            if pattern.firstMatch(in: url, range: range) != nil {
                return url
            }
        }
        return nil
    }

    private static let resourceSnifferScript = #"""
    (() => {
      const urls = new Set();
      try {
        performance.getEntriesByType('resource').forEach(entry => {
          if (entry && entry.name) urls.add(entry.name);
        });
      } catch (e) {}
      document.querySelectorAll('[src],[href],source,video,audio,img').forEach(el => {
        const value = el.currentSrc || el.src || el.href || el.getAttribute('src') || el.getAttribute('href');
        if (value) urls.add(value);
      });
      return JSON.stringify(Array.from(urls));
    })();
    """#
}

private enum WebViewFetchError: LocalizedError {
    case timeout
    case noHTML
    case invalidState

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "WebView 加载超时"
        case .noHTML:
            return "WebView 未返回 HTML"
        case .invalidState:
            return "WebView 请求状态异常"
        }
    }
}

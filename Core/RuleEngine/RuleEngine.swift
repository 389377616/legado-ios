//
//  RuleEngine.swift
//  Legado-iOS
//
//  书源规则解析引擎
//

import Foundation
import JavaScriptCore
import SwiftSoup
import Kanna

// MARK: - 元素上下文（用于列表项提取）
class ElementContext {
    var element: Any      // SwiftSoup.Element, JSON dict, 或 String
    var baseUrl: String?
    
    init(element: Any, baseUrl: String? = nil) {
        self.element = element
        self.baseUrl = baseUrl
    }
}

// MARK: - 结果类型
enum RuleResult {
    case string(String)
    case list([String])
    case none
    
    var string: String? {
        if case .string(let value) = self { return value }
        return nil
    }
    
    var list: [String]? {
        if case .list(let value) = self { return value }
        return nil
    }
}

// MARK: - 执行上下文
class ExecutionContext {
    var document: Any?
    var jsonString: String?
    var jsonDict: [String: Any]?
    var baseURL: URL?
    var variables: [String: String] = [:]
    var lastResult: RuleResult = .none
    
    lazy var jsContext: JSContext = {
        let context = JSContext()!
        
        // 注入getVar/setVar
        context.setValue({ [weak self] (key: String) -> String in
            self?.variables[key] ?? ""
        }, forKey: "getVar")
        
        context.setValue({ [weak self] (key: String, value: String) in
            self?.variables[key] = value
        }, forKey: "setVar")
        
        // 注入 result
        context.setValue({ [weak self] () -> String? in
            self?.lastResult.string
        }, forKey: "result")
        
        return context
    }()
}

// MARK: - 解析器协议
protocol RuleExecutor {
    var kind: RuleKind { get }
    func canExecute(_ rule: String) -> Bool
    func execute(_ rule: String, context: ExecutionContext) throws -> RuleResult
}

enum RuleKind: String, CaseIterable {
    case jsonPath = "json"
    case xpath = "xpath"
    case css = "css"
    case regex = "regex"
    case js = "js"
}

// MARK: - 规则引擎
class RuleEngine {
    private var executors: [RuleExecutor] = []
    
    init() {
        // 按优先级注册解析器
        executors.append(JSONPathParser())
        executors.append(XPathParser())
        executors.append(CSSParser())
        executors.append(RegexParser())
        executors.append(JavaScriptParser())
    }
    
    func execute(
        rules: [String],
        context: ExecutionContext
    ) throws -> RuleResult {
        var lastResult: RuleResult = .none
        
        for rule in rules {
            guard let executor = executors.first(where: { $0.canExecute(rule) }) else {
                continue
            }
            
            do {
                lastResult = try executor.execute(rule, context: context)
                context.lastResult = lastResult
            } catch {
                print("规则执行错误 [\(rule)]: \(error)")
            }
        }
        
        return lastResult
    }
    
    func executeSingle(
        rule: String,
        context: ExecutionContext
    ) throws -> RuleResult {
        guard let executor = executors.first(where: { $0.canExecute(rule) }) else {
            throw RuleError.unsupportedRule(rule)
        }
        
        return try executor.execute(rule, context: context)
    }
    
    // MARK: - 从 HTML/JSON 中提取元素列表
    
    /// 提取元素列表（用于书籍列表、章节列表等）
    /// - Parameters:
    ///   - ruleStr: 列表规则，如 CSS 选择器 "div.book-item" 或 JSONPath "$.list"
    ///   - body: HTML 或 JSON 字符串
    ///   - baseUrl: 基础 URL
    /// - Returns: 元素上下文数组
    func getElements(ruleStr: String?, body: String, baseUrl: String?) throws -> [ElementContext] {
        guard let ruleStr = ruleStr, !ruleStr.isEmpty else { return [] }
        
        let isJson = body.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") ||
                     body.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[")
        
        if isJson {
            return try getJsonElements(ruleStr: ruleStr, body: body)
        } else {
            return try getHtmlElements(ruleStr: ruleStr, body: body, baseUrl: baseUrl)
        }
    }
    
    /// 从 HTML 提取元素列表
    private func getHtmlElements(ruleStr: String, body: String, baseUrl: String?) throws -> [ElementContext] {
        let doc = try SwiftSoup.parse(body)
        if let base = baseUrl { try? doc.setBaseUri(base) }
        
        // 处理反向列表（以 - 开头）
        var rule = ruleStr
        var reverse = false
        if rule.hasPrefix("-") {
            reverse = true
            rule = String(rule.dropFirst())
        }
        if rule.hasPrefix("+") {
            rule = String(rule.dropFirst())
        }
        
        // 支持 XPath 和 CSS
        var elements: [ElementContext]
        if rule.hasPrefix("//") {
            // XPath
            let kannaDoc = try Kanna.HTML(html: body, encoding: .utf8)
            elements = kannaDoc.xpath(rule).compactMap { node -> ElementContext? in
                guard let html = node.toHTML else { return nil }
                return ElementContext(element: html, baseUrl: baseUrl)
            }
        } else {
            // CSS
            let selected = try doc.select(rule)
            elements = selected.array().map { ElementContext(element: $0, baseUrl: baseUrl) }
        }
        
        if reverse { elements.reverse() }
        return elements
    }
    
    /// 从 JSON 提取元素列表
    private func getJsonElements(ruleStr: String, body: String) throws -> [ElementContext] {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            throw RuleError.noDocument
        }
        
        let path = ruleStr.replacingOccurrences(of: "$.", with: "")
        let keys = path.split(separator: ".").map { String($0) }
        
        var current: Any? = json
        for key in keys {
            if let dict = current as? [String: Any] {
                current = dict[key]
            } else if let array = current as? [Any], let index = Int(key) {
                current = index < array.count ? array[index] : nil
            } else {
                break
            }
        }
        
        if let array = current as? [[String: Any]] {
            return array.map { ElementContext(element: $0) }
        } else if let array = current as? [Any] {
            return array.map { ElementContext(element: $0) }
        }
        
        return []
    }
    
    // MARK: - 在元素上下文中提取字符串
    
    /// 从单个元素中提取字符串（用于从列表项中提取书名、作者等）
    func getString(ruleStr: String?, elementContext: ElementContext, baseUrl: String? = nil) -> String {
        guard let ruleStr = ruleStr, !ruleStr.isEmpty else { return "" }
        
        // 支持 && 连接（串联多个规则结果）
        if ruleStr.contains("&&") {
            let parts = ruleStr.components(separatedBy: "&&")
            return parts.compactMap { getString(ruleStr: $0.trimmingCharacters(in: .whitespaces), elementContext: elementContext, baseUrl: baseUrl) }
                       .filter { !$0.isEmpty }
                       .joined(separator: "\n")
        }
        
        // 支持 || 连接（取第一个非空结果）
        if ruleStr.contains("||") {
            let parts = ruleStr.components(separatedBy: "||")
            for part in parts {
                let result = getString(ruleStr: part.trimmingCharacters(in: .whitespaces), elementContext: elementContext, baseUrl: baseUrl)
                if !result.isEmpty { return result }
            }
            return ""
        }
        
        do {
            if let element = elementContext.element as? SwiftSoup.Element {
                return try getStringFromElement(ruleStr: ruleStr, element: element, baseUrl: baseUrl)
            } else if let dict = elementContext.element as? [String: Any] {
                return getStringFromJson(ruleStr: ruleStr, json: dict)
            } else if let html = elementContext.element as? String {
                let context = ExecutionContext()
                context.document = try SwiftSoup.parse(html)
                context.baseURL = baseUrl.flatMap { URL(string: $0) }
                let result = try executeSingle(rule: ruleStr, context: context)
                return result.string ?? ""
            }
        } catch {
            print("getString 错误 [\(ruleStr)]: \(error)")
        }
        
        return ""
    }
    
    /// 从 SwiftSoup Element 中提取字符串
    private func getStringFromElement(ruleStr: String, element: SwiftSoup.Element, baseUrl: String?) throws -> String {
        // 解析 CSS 选择器和属性
        var rule = ruleStr
        var attr = "text"
        
        // 检查 @attr 后缀
        if let atRange = rule.range(of: "@", options: .backwards) {
            let possibleAttr = String(rule[atRange.upperBound...])
            // 确保不是 CSS 选择器中的 @ 符号
            if !possibleAttr.contains(" ") && !possibleAttr.contains(".") {
                attr = possibleAttr
                rule = String(rule[..<atRange.lowerBound])
            }
        }
        
        // 空选择器直接从当前元素取
        if rule.isEmpty {
            return try extractAttr(element: element, attr: attr, baseUrl: baseUrl)
        }
        
        // 执行选择器
        guard let found = try element.select(rule).first() else {
            return ""
        }
        
        return try extractAttr(element: found, attr: attr, baseUrl: baseUrl)
    }
    
    /// 从元素提取指定属性
    private func extractAttr(element: SwiftSoup.Element, attr: String, baseUrl: String?) throws -> String {
        switch attr.lowercased() {
        case "text":
            return try element.text()
        case "textnodes":
            return element.textNodes().map { $0.text() }.joined(separator: "\n")
        case "html", "innerhtml":
            return try element.html()
        case "outerhtml":
            return try element.outerHtml()
        case "href":
            let href = try element.attr("href")
            return resolveUrl(href, baseUrl: baseUrl)
        case "src":
            let src = try element.attr("src")
            return resolveUrl(src, baseUrl: baseUrl)
        case "abs:href":
            return try element.attr("abs:href")
        case "abs:src":
            return try element.attr("abs:src")
        default:
            return try element.attr(attr)
        }
    }
    
    /// 从 JSON 字典中提取字符串
    private func getStringFromJson(ruleStr: String, json: [String: Any]) -> String {
        let path = ruleStr.replacingOccurrences(of: "$.", with: "")
        let keys = path.split(separator: ".").map { String($0) }
        
        var current: Any? = json
        for key in keys {
            if let dict = current as? [String: Any] {
                current = dict[key]
            } else {
                return ""
            }
        }
        
        if let str = current as? String { return str }
        if let num = current as? NSNumber { return num.stringValue }
        return ""
    }
    
    /// 解析相对 URL
    private func resolveUrl(_ url: String, baseUrl: String?) -> String {
        if url.hasPrefix("http") { return url }
        guard let base = baseUrl, let baseURL = URL(string: base) else { return url }
        return URL(string: url, relativeTo: baseURL)?.absoluteString ?? url
    }
    
    // MARK: - 获取字符串列表
    
    /// 获取字符串列表（用于目录列表等）
    func getStringList(ruleStr: String?, body: String, baseUrl: String?) throws -> [String] {
        guard let ruleStr = ruleStr, !ruleStr.isEmpty else { return [] }
        
        let context = ExecutionContext()
        let isJson = body.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") ||
                     body.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[")
        
        if isJson {
            context.jsonString = body
        } else {
            context.document = try SwiftSoup.parse(body)
        }
        context.baseURL = baseUrl.flatMap { URL(string: $0) }
        
        let result = try executeSingle(rule: ruleStr, context: context)
        return result.list ?? (result.string.map { [$0] } ?? [])
    }
}

// MARK: - CSS 解析器 (SwiftSoup)
class CSSParser: RuleExecutor {
    var kind: RuleKind { .css }
    
    func canExecute(_ rule: String) -> Bool {
        return !rule.hasPrefix("//") && !rule.hasPrefix("$.") && !rule.hasPrefix("{{")
    }
    
    func execute(_ rule: String, context: ExecutionContext) throws -> RuleResult {
        guard let document = context.document as? SwiftSoup.Document else {
            throw RuleError.noDocument
        }
        
        let (selector, attr) = parseSelector(rule)
        let elements = try document.select(selector)
        
        if let first = elements.first() {
            switch attr {
            case "text":
                return .string(try first.text())
            case "html":
                return .string(try first.html())
            case "href":
                return .string(try first.attr("href"))
            case "src":
                return .string(try first.attr("src"))
            default:
                return .string(try first.text())
            }
        }
        
        return .none
    }
    
    private func parseSelector(_ rule: String) -> (String, String) {
        var selector = rule
        var attr = "text"
        
        if let range = rule.range(of: "@") {
            selector = String(rule[..<range.lowerBound])
            attr = String(rule[range.upperBound...])
        }
        
        return (selector, attr)
    }
}

// MARK: - XPath 解析器 (Kanna)
class XPathParser: RuleExecutor {
    var kind: RuleKind { .xpath }
    
    func canExecute(_ rule: String) -> Bool {
        return rule.hasPrefix("//")
    }
    
    func execute(_ rule: String, context: ExecutionContext) throws -> RuleResult {
        guard let html = context.document as? String else {
            throw RuleError.noDocument
        }
        
        let doc = try Kanna.HTML(html: html, encoding: .utf8)
        
        var results: [String] = []
        for node in doc.xpath(rule) {
            if let text = node.text {
                results.append(text)
            }
        }
        
        if results.count == 1 {
            return .string(results[0])
        } else if !results.isEmpty {
            return .list(results)
        }
        
        return .none
    }
}

// MARK: - JSONPath 解析器
class JSONPathParser: RuleExecutor {
    var kind: RuleKind { .jsonPath }
    
    func canExecute(_ rule: String) -> Bool {
        return rule.hasPrefix("$.")
    }
    
    func execute(_ rule: String, context: ExecutionContext) throws -> RuleResult {
        if context.jsonDict == nil, let jsonString = context.jsonString {
            let data = jsonString.data(using: .utf8)!
            context.jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        }
        
        guard let dict = context.jsonDict else {
            throw RuleError.noDocument
        }
        
        let value = evaluateJSONPath(rule, json: dict)
        
        if let string = value as? String {
            return .string(string)
        } else if let array = value as? [Any] {
            let strings = array.compactMap { $0 as? String }
            return .list(strings)
        }
        
        return .none
    }
    
    private func evaluateJSONPath(_ path: String, json: [String: Any]) -> Any? {
        let cleanPath = path.replacingOccurrences(of: "$.", with: "")
        let keys = cleanPath.split(separator: ".").map { String($0) }
        
        var current: Any? = json
        for key in keys {
            guard let dict = current as? [String: Any] else { return nil }
            
            if let bracketRange = key.range(of: "["), key.hasSuffix("]") {
                let arrayKey = String(key[..<bracketRange.lowerBound])
                let indexStr = String(key[bracketRange.upperBound...].dropLast())
                guard let index = Int(indexStr),
                      let array = dict[arrayKey] as? [[String: Any]],
                      index < array.count else { return nil }
                current = array[index]
            } else {
                current = dict[key]
            }
        }
        
        return current
    }
}

// MARK: - 正则解析器
class RegexParser: RuleExecutor {
    var kind: RuleKind { .regex }
    
    func canExecute(_ rule: String) -> Bool {
        return rule.hasPrefix("regex:") || rule.contains("{{regex")
    }
    
    func execute(_ rule: String, context: ExecutionContext) throws -> RuleResult {
        guard let input = context.lastResult.string ?? (context.document as? String) else {
            throw RuleError.noDocument
        }
        
        let pattern = rule.replacingOccurrences(of: "regex:", with: "")
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            throw RuleError.invalidRule("无效正则：\(pattern)")
        }
        
        let range = NSRange(input.startIndex..., in: input)
        var results: [String] = []
        
        for match in regex.matches(in: input, range: range) {
            if let matchRange = Range(match.range, in: input) {
                results.append(String(input[matchRange]))
            }
        }
        
        if results.count == 1 {
            return .string(results[0])
        } else if !results.isEmpty {
            return .list(results)
        }
        
        return .none
    }
}

// MARK: - JavaScript 解析器
class JavaScriptParser: RuleExecutor {
    var kind: RuleKind { .js }
    
    func canExecute(_ rule: String) -> Bool {
        return rule.contains("{{js") || rule.contains("<js>")
    }
    
    func execute(_ rule: String, context: ExecutionContext) throws -> RuleResult {
        let jsCode = extractJS(rule)
        
        context.jsContext.setValue(context.lastResult.string, forKey: "result")
        context.jsContext.setValue(context.baseURL?.absoluteString, forKey: "baseUrl")
        
        let jsValue = context.jsContext.evaluateScript(jsCode)
        
        if let string = jsValue?.toString() {
            return .string(string)
        }
        
        return .none
    }
    
    private func extractJS(_ rule: String) -> String {
        let patterns = [
            #"{{js(.*?)}}"#,
            #"<js>(.*?)</js>"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(
                in: rule,
                range: NSRange(rule.startIndex..., in: rule)
               ),
               let range = Range(match.range(at: 1), in: rule) {
                return String(rule[range]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        return rule
    }
}

// MARK: - 错误类型
enum RuleError: LocalizedError {
    case noDocument
    case invalidRule(String)
    case unsupportedRule(String)
    case executionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noDocument: return "缺少文档"
        case .invalidRule(let rule): return "无效规则：\(rule)"
        case .unsupportedRule(let rule): return "不支持的规则：\(rule)"
        case .executionFailed(let error): return "执行失败：\(error)"
        }
    }
}

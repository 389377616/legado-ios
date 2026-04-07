import Foundation
import SwiftSoup

struct HTMLToTextConverter {
    
    static func convert(html: String, baseURL: URL? = nil) -> String {
        do {
            let doc = try SwiftSoup.parse(html)
            try doc.select("script, style, nav, header, footer").remove()
            
            let blockElements = ["p", "div", "br", "h1", "h2", "h3", "h4", "h5", "h6", "li", "tr"]
            for tag in blockElements {
                let elements = try doc.select(tag)
                for element in elements.array() {
                    try element.after("\n")
                }
            }
            
            var text = try doc.text()
            text = text.replacingOccurrences(of: "[ \t]+", with: " ", options: .regularExpression)
            text = text.replacingOccurrences(of: "\n[ \t]+", with: "\n", options: .regularExpression)
            text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            return text
        } catch {
            return extractTextSimple(html: html)
        }
    }
    
    /// 对齐 Android HtmlFormatter.formatKeepImg：保留 <img> 标签，绝对化 URL，移除其他 HTML
    static func formatKeepImg(html: String, baseURL: URL? = nil) -> String {
        guard !html.isEmpty else { return "" }
        
        var result = html
        
        // HTML 实体处理
        result = result.replacingOccurrences(of: "(&nbsp;)+", with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: "(&ensp;|&emsp;)", with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: "(&thinsp;|&zwnj;|&zwj;|\u{2009}|\u{200C}|\u{200D})", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "</?(?:div|p|br|hr|h\\d|article|dd|dl)[^>]*>", with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: "<!--[^>]*-->", with: "", options: .regularExpression)
        
        // 匹配三种 <img> 模式：模板URL、src/data-src、data-* 属性（对齐 Android formatImagePattern）
        let imgPattern = #"<img[^>]*\ssrc\s*=\s*['"]([^'"{>]*\{(?:[^{}]|\{[^}>]+\})+\})['"][^>]*>|<img[^>]*\s(?:data-src|src)\s*=\s*['"]([^'">]+)['"][^>]*>|<img[^>]*\sdata-[^=>]*=\s*['"]([^'">]*)['"][^>]*>"#
        
        guard let imgRegex = try? NSRegularExpression(pattern: imgPattern, options: [.caseInsensitive]) else {
            return result
        }
        
        let range = NSRange(result.startIndex..., in: result)
        let matches = imgRegex.matches(in: result, options: [], range: range)
        
        var processedHTML = ""
        var lastEnd = result.startIndex
        
        for match in matches {
            processedHTML += String(result[lastEnd..<result.index(result.startIndex, offsetBy: match.range.lowerBound)])
            
            var imgURL: String?
            var param = ""
            
            if let group1Range = Range(match.range(at: 1), in: result) {
                let templateURL = String(result[group1Range])
                if let paramMatch = templateURL.range(of: #"\?.*$"#, options: .regularExpression) {
                    param = String(templateURL[paramMatch])
                    imgURL = String(templateURL[templateURL.startIndex..<paramMatch.lowerBound])
                } else {
                    imgURL = templateURL
                }
            } else if let group2Range = Range(match.range(at: 2), in: result) {
                imgURL = String(result[group2Range])
            } else if let group3Range = Range(match.range(at: 3), in: result) {
                imgURL = String(result[group3Range])
            }
            
            if let imgURL = imgURL, !imgURL.isEmpty {
                processedHTML += "<img src=\"\(getAbsoluteURL(baseURL: baseURL, relativeURL: imgURL) + param)\">"
            }
            
            lastEnd = result.index(result.startIndex, offsetBy: match.range.upperBound)
        }
        
        processedHTML += String(result[lastEnd...])
        
        // 移除非 img 标签
        processedHTML = processedHTML.replacingOccurrences(of: #"</?(?!img)[a-zA-Z]+(?=[ >])[^<>]*>"#, with: "", options: .regularExpression)
        
        // 格式化换行
        processedHTML = processedHTML.replacingOccurrences(of: "\\s*\\n+\\s*", with: "\n　　", options: .regularExpression)
        processedHTML = processedHTML.replacingOccurrences(of: "^[\\n\\s]+", with: "　　", options: .regularExpression)
        processedHTML = processedHTML.replacingOccurrences(of: "[\\n\\s]+$", with: "", options: .regularExpression)
        
        return processedHTML
    }
    
    private static func getAbsoluteURL(baseURL: URL?, relativeURL: String) -> String {
        guard let baseURL = baseURL else { return relativeURL }
        if relativeURL.hasPrefix("http://") || relativeURL.hasPrefix("https://") { return relativeURL }
        return URL(string: relativeURL, relativeTo: baseURL)?.absoluteString ?? relativeURL
    }
    
    static func convert(file url: URL) throws -> String {
        let html = try String(contentsOf: url, encoding: .utf8)
        return convert(html: html, baseURL: url.deletingLastPathComponent())
    }
    
    private static func extractTextSimple(html: String) -> String {
        var text = html

        text = text.replacingOccurrences(
            of: "(?s)<script[^>]*>.*?</script>",
            with: "",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: "(?s)<style[^>]*>.*?</style>",
            with: "",
            options: .regularExpression
        )

        let blockTags = ["p", "div", "br", "h1", "h2", "h3", "h4", "h5", "h6", "li", "tr", "section", "article"]
        for tag in blockTags {
            text = text.replacingOccurrences(of: "</\(tag)>", with: "</\(tag)>\n", options: .regularExpression)
            if tag == "br" {
                text = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            }
        }
        
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        text = text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        
        text = text.replacingOccurrences(of: "[ \t]+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\n[ \t]+", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return text
    }
}
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
    
    static func convert(file url: URL) throws -> String {
        let html = try String(contentsOf: url, encoding: .utf8)
        return convert(html: html, baseURL: url.deletingLastPathComponent())
    }
    
    private static func extractTextSimple(html: String) -> String {
        var text = html
        
        text = text.replacingOccurrences(
            of: "<script[^>]*>.*?</script>",
            with: "",
            options: [.regularExpression, .dotMatchesLineSeparators]
        )
        text = text.replacingOccurrences(
            of: "<style[^>]*>.*?</style>",
            with: "",
            options: [.regularExpression, .dotMatchesLineSeparators]
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
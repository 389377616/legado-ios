import Foundation
import UIKit
#if canImport(ZIPFoundation)
import ZIPFoundation
#endif

class EPUBParser {
    
    struct EPUBBook {
        let title: String
        let author: String
        let coverImage: Data?
        let chapters: [EPUBChapter]
        let metadata: EPUBMetadata
        let tableOfContents: [TOCItem]
        let epubDirectory: URL
    }
    
    struct EPUBMetadata {
        let title: String
        let author: String
        let publisher: String?
        let language: String?
        let description: String?
        let rights: String?
        let date: String?
        let identifier: String?
    }
    
    struct EPUBChapter {
        let id: String
        let title: String
        let href: String
        let htmlPath: String
        let index: Int
        let mediaType: String
    }
    
    struct TOCItem {
        let title: String
        let href: String
        let level: Int
        let children: [TOCItem]
    }
    
    static func parse(file url: URL) async throws -> EPUBBook {
        return try parseSync(file: url)
    }
    
    static func parseSync(file url: URL, bookId: UUID? = nil) throws -> EPUBBook {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw EPUBError.fileNotFound
        }
        
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let epubDir = documents.appendingPathComponent("epubs").appendingPathComponent(bookId?.uuidString ?? UUID().uuidString)
        
        if FileManager.default.fileExists(atPath: epubDir.path) {
            try? FileManager.default.removeItem(at: epubDir)
        }
        try FileManager.default.createDirectory(at: epubDir, withIntermediateDirectories: true)
        
        try unzipFile(at: url, to: epubDir)
        
        let containerPath = epubDir.appendingPathComponent("META-INF/container.xml")
        let opfRelativePath = try parseContainer(at: containerPath)
        let opfPath = epubDir.appendingPathComponent(opfRelativePath)
        let basePath = opfPath.deletingLastPathComponent()
        
        let (metadata, manifest, spine) = try parseOPF(at: opfPath)
        let toc = try parseNavigation(manifest: manifest, basePath: basePath)
        let chapters = try parseChapters(spine: spine, manifest: manifest, basePath: basePath, epubDir: epubDir)
        let coverImage = try extractCover(manifest: manifest, metadata: metadata, basePath: basePath)
        
        return EPUBBook(
            title: metadata.title,
            author: metadata.author,
            coverImage: coverImage,
            chapters: chapters,
            metadata: metadata,
            tableOfContents: toc,
            epubDirectory: epubDir
        )
    }
    
    private static func unzipFile(at sourceURL: URL, to destinationURL: URL) throws {
        #if canImport(ZIPFoundation)
        do {
            try FileManager.default.unzipItem(at: sourceURL, to: destinationURL)
        } catch {
            throw EPUBError.parseFailed("解压失败：\(error.localizedDescription)")
        }
        #else
        throw EPUBError.parseFailed("缺少 ZIPFoundation 依赖")
        #endif
    }
    
    private static func parseContainer(at url: URL) throws -> String {
        let content = try String(contentsOf: url, encoding: .utf8)
        guard let opfPath = extractFirstMatch(in: content, pattern: "full-path=\"([^\"]+)\"") else {
            throw EPUBError.parseFailed("找不到 content.opf")
        }
        return opfPath
    }
    
    private static func parseOPF(at url: URL) throws -> (EPUBMetadata, [String: ManifestItem], [String]) {
        let content = try String(contentsOf: url, encoding: .utf8)
        
        let metadata = EPUBMetadata(
            title: extractMetadata(content: content, tag: "dc:title") ?? "未知书籍",
            author: extractMetadata(content: content, tag: "dc:creator") ?? "未知作者",
            publisher: extractMetadata(content: content, tag: "dc:publisher"),
            language: extractMetadata(content: content, tag: "dc:language"),
            description: extractMetadata(content: content, tag: "dc:description"),
            rights: extractMetadata(content: content, tag: "dc:rights"),
            date: extractMetadata(content: content, tag: "dc:date"),
            identifier: extractMetadata(content: content, tag: "dc:identifier")
        )
        
        var manifest: [String: ManifestItem] = [:]
        let itemPattern = "<item\\s+([^>]+)/?>"
        let itemRegex = try NSRegularExpression(pattern: itemPattern)
        let items = itemRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))
        
        for match in items {
            guard let range = Range(match.range(at: 1), in: content) else { continue }
            let attributes = String(content[range])
            
            if let id = extractAttribute(attributes, name: "id"),
               let href = extractAttribute(attributes, name: "href"),
               let mediaType = extractAttribute(attributes, name: "media-type") {
                let properties = extractAttribute(attributes, name: "properties")
                manifest[id] = ManifestItem(id: id, href: href, mediaType: mediaType, properties: properties)
            }
        }
        
        var spine: [String] = []
        if let spineContent = extractFirstMatch(in: content, pattern: "<spine[^>]*>(.*?)</spine>") {
            let idrefPattern = "idref=\"([^\"]+)\""
            let idrefRegex = try NSRegularExpression(pattern: idrefPattern)
            let idrefs = idrefRegex.matches(in: spineContent, range: NSRange(spineContent.startIndex..., in: spineContent))
            
            for match in idrefs {
                if let range = Range(match.range(at: 1), in: spineContent) {
                    spine.append(String(spineContent[range]))
                }
            }
        }
        
        return (metadata, manifest, spine)
    }
    
    private static func parseNavigation(manifest: [String: ManifestItem], basePath: URL) throws -> [TOCItem] {
        if let ncxItem = manifest.first(where: { $0.value.mediaType == "application/x-dtbncx+xml" })?.value {
            let ncxPath = basePath.appendingPathComponent(ncxItem.href)
            return try parseNCX(at: ncxPath)
        }
        
        if let navItem = manifest.first(where: {
            $0.value.mediaType == "application/xhtml+xml" && $0.value.properties?.contains("nav") == true
        })?.value {
            let navPath = basePath.appendingPathComponent(navItem.href)
            return try parseNav(at: navPath)
        }
        
        return []
    }
    
    private static func parseNCX(at url: URL) throws -> [TOCItem] {
        let content = try String(contentsOf: url, encoding: .utf8)
        var items: [TOCItem] = []
        
        let navPointPattern = "<navPoint[^>]*>(.*?)</navPoint>"
        let navPointRegex = try NSRegularExpression(pattern: navPointPattern, options: [.dotMatchesLineSeparators])
        let navPoints = navPointRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))
        
        for match in navPoints {
            guard let range = Range(match.range(at: 1), in: content) else { continue }
            let navPointContent = String(content[range])
            
            if let title = extractFirstMatch(in: navPointContent, pattern: "<text[^>]*>([^<]+)</text>"),
               let href = extractFirstMatch(in: navPointContent, pattern: "src=\"([^\"]+)\"") {
                items.append(TOCItem(title: title, href: href, level: 1, children: []))
            }
        }
        
        return items
    }
    
    private static func parseNav(at url: URL) throws -> [TOCItem] {
        let content = try String(contentsOf: url, encoding: .utf8)
        var items: [TOCItem] = []
        
        let linkPattern = "<a[^>]+href=\"([^\"]+)\"[^>]*>([^<]+)</a>"
        let linkRegex = try NSRegularExpression(pattern: linkPattern)
        let links = linkRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))
        
        for match in links {
            guard let hrefRange = Range(match.range(at: 1), in: content),
                  let titleRange = Range(match.range(at: 2), in: content) else { continue }
            
            items.append(TOCItem(title: String(content[titleRange]), href: String(content[hrefRange]), level: 1, children: []))
        }
        
        return items
    }
    
    private static func parseChapters(spine: [String], manifest: [String: ManifestItem], basePath: URL, epubDir: URL) throws -> [EPUBChapter] {
        var chapters: [EPUBChapter] = []
        
        for (index, itemId) in spine.enumerated() {
            guard let item = manifest[itemId] else { continue }
            
            let chapterPath = basePath.appendingPathComponent(item.href)
            var chapterTitle = "第 \(index + 1) 章"
            
            if FileManager.default.fileExists(atPath: chapterPath.path) {
                let htmlContent = try String(contentsOf: chapterPath, encoding: .utf8)
                
                if let title = extractFirstMatch(in: htmlContent, pattern: "<title[^>]*>([^<]+)</title>") {
                    chapterTitle = title
                } else if let h1 = extractFirstMatch(in: htmlContent, pattern: "<h1[^>]*>([^<]+)</h1>") {
                    chapterTitle = h1
                }
            }
            
            chapters.append(EPUBChapter(
                id: itemId,
                title: chapterTitle,
                href: item.href,
                htmlPath: item.href,
                index: index,
                mediaType: item.mediaType
            ))
        }
        
        return chapters
    }
    
    private static func extractCover(manifest: [String: ManifestItem], metadata: EPUBMetadata, basePath: URL) -> Data? {
        if let coverItem = manifest.first(where: { $0.value.properties?.contains("cover-image") == true })?.value {
            let coverPath = basePath.appendingPathComponent(coverItem.href)
            if let data = try? Data(contentsOf: coverPath) { return data }
        }
        
        for (id, item) in manifest {
            if id.lowercased().contains("cover") && item.mediaType.hasPrefix("image/") {
                let coverPath = basePath.appendingPathComponent(item.href)
                if let data = try? Data(contentsOf: coverPath) { return data }
            }
        }
        
        return nil
    }
    
    private static func extractFirstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }
    
    private static func extractMetadata(content: String, tag: String) -> String? {
        return extractFirstMatch(in: content, pattern: "<\(tag)[^>]*>([^<]+)</\(tag)>")
    }
    
    private static func extractAttribute(_ text: String, name: String) -> String? {
        return extractFirstMatch(in: text, pattern: "\(name)=\"([^\"]+)\"")
    }
}

private struct ManifestItem {
    let id: String
    let href: String
    let mediaType: String
    let properties: String?
}

enum EPUBError: LocalizedError {
    case fileNotFound
    case invalidFormat
    case parseFailed(String)
    case chapterNotFound
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound: return "EPUB 文件不存在"
        case .invalidFormat: return "无效的 EPUB 格式"
        case .parseFailed(let reason): return "解析失败：\(reason)"
        case .chapterNotFound: return "章节不存在"
        }
    }
}
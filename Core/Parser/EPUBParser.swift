//
//  EPUBParser.swift
//  Legado-iOS
//
//  EPUB 解析器

import Foundation
import UIKit
#if canImport(ZIPFoundation)
import ZIPFoundation
#endif

/// EPUB 解析器
class EPUBParser {
    
    struct EPUBBook {
        let title: String
        let author: String
        let coverImage: Data?
        let chapters: [EPUBChapter]
        let metadata: [String: String]
    }
    
    struct EPUBChapter {
        let title: String
        let href: String
        let content: String
        let index: Int
    }
    
    static func parse(file url: URL) async throws -> EPUBBook {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw EPUBError.fileNotFound
        }
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        try unzipFile(at: url, to: tempDir)
        
        let containerPath = tempDir.appendingPathComponent("META-INF/container.xml")
        let opfPath = try parseContainer(at: containerPath, basePath: tempDir)
        
        return try parseOPF(at: opfPath, basePath: tempDir)
    }
    
    private static func unzipFile(at sourceURL: URL, to destinationURL: URL) throws {
#if canImport(ZIPFoundation)
        do {
            try FileManager.default.unzipItem(at: sourceURL, to: destinationURL)
        } catch {
            throw EPUBError.parseFailed("解压失败：\(error.localizedDescription)")
        }
#else
        throw EPUBError.parseFailed("缺少 ZIPFoundation 依赖，无法解压 EPUB")
#endif
    }
    
    private static func parseContainer(at url: URL, basePath: URL) throws -> URL {
        let content = try String(contentsOf: url, encoding: .utf8)
        
        guard let opfPath = extractFirstMatch(in: content, pattern: #"full-path="([^"]+)""#) else {
            throw EPUBError.parseFailed("找不到 content.opf")
        }
        
        return basePath.appendingPathComponent(opfPath)
    }
    
    private static func parseOPF(at url: URL, basePath: URL) throws -> EPUBBook {
        let content = try String(contentsOf: url, encoding: .utf8)
        
        let title = extractFirstMatch(in: content, pattern: #"<dc:title[^>]*>([^<]+)</dc:title>"#) ?? "未知书籍"
        let author = extractFirstMatch(in: content, pattern: #"<dc:creator[^>]*>([^<]+)</dc:creator>"#) ?? "未知作者"
        
        var coverHref: String?
        if let coverId = extractFirstMatch(in: content, pattern: #"meta\s+name="cover"\s+content="([^"]+)""#) {
            let itemPattern = #"id="\Q\(coverId)\E"[^>]*href="([^"]+)""#
            coverHref = extractFirstMatch(in: content, pattern: itemPattern)
        }
        
        var chapters: [EPUBChapter] = []
        let spineRegex = try NSRegularExpression(pattern: #"<itemref\s+([^>]+)>"#, options: [])
        let matches = spineRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))
        
        for (index, match) in matches.enumerated() {
            guard let attrRange = Range(match.range(at: 1), in: content) else { continue }
            let attributes = String(content[attrRange])
            
            guard let itemId = extractFirstMatch(in: attributes, pattern: #"idref="([^"]+)""#) else { continue }
            
            let itemPattern = #"id="\Q\(itemId)\E"[^>]*href="([^"]+)"[^>]*media-type="text/html""#
            if let href = extractFirstMatch(in: content, pattern: itemPattern) {
                let chapterPath = basePath.deletingLastPathComponent().appendingPathComponent(href)
                
                var chapterContent = ""
                if FileManager.default.fileExists(atPath: chapterPath.path) {
                    chapterContent = try String(contentsOf: chapterPath, encoding: .utf8)
                    chapterContent = stripHTML(content: chapterContent)
                }
                
                chapters.append(EPUBChapter(title: "第 \(index + 1) 章", href: href, content: chapterContent, index: index))
            }
        }
        
        var coverData: Data?
        if let coverHref = coverHref {
            let coverPath = basePath.deletingLastPathComponent().appendingPathComponent(coverHref)
            coverData = try? Data(contentsOf: coverPath)
        }
        
        var metadata: [String: String] = [:]
        metadata["publisher"] = extractMetadataTag(content: content, tag: "dc:publisher")
        metadata["language"] = extractMetadataTag(content: content, tag: "dc:language")
        metadata["description"] = extractMetadataTag(content: content, tag: "dc:description")
        
        return EPUBBook(title: title, author: author, coverImage: coverData, chapters: chapters, metadata: metadata)
    }
    
    private static func extractFirstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }
    
    private static func extractMetadataTag(content: String, tag: String) -> String? {
        extractFirstMatch(in: content, pattern: "<\(tag)[^>]*>([^<]+)</\(tag)>")
    }
    
    private static func stripHTML(content: String) -> String {
        guard let data = content.data(using: .utf8) else { return content }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil)
        return attributedString?.string ?? content
    }
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

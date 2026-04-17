import Foundation
import UIKit
import SwiftSoup
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
        let resources: [String: EPUBResource]
        let spine: [String]
        let manifest: [String: ManifestItem]
        let opfBasePath: URL
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
        let startFragmentId: String?
        let endFragmentId: String?
        let nextUrl: String?
        let isVolume: Bool
    }
    
    struct EPUBResource {
        let id: String
        let href: String
        let mediaType: String
        let properties: String?
        let absolutePath: URL
    }
    
    struct TOCItem {
        let title: String
        let href: String
        let fragmentId: String?
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
        let resources = buildResources(manifest: manifest, basePath: basePath)
        let toc = try parseNavigation(manifest: manifest, basePath: basePath, spine: spine)
        let chapters = try parseChaptersWithFragmentId(
            spine: spine,
            manifest: manifest,
            toc: toc,
            basePath: basePath,
            epubDir: epubDir
        )
        let coverImage = try extractCover(manifest: manifest, metadata: metadata, basePath: basePath)
        
        return EPUBBook(
            title: metadata.title,
            author: metadata.author,
            coverImage: coverImage,
            chapters: chapters,
            metadata: metadata,
            tableOfContents: toc,
            epubDirectory: epubDir,
            resources: resources,
            spine: spine,
            manifest: manifest,
            opfBasePath: basePath
        )
    }
    
    private static func buildResources(manifest: [String: ManifestItem], basePath: URL) -> [String: EPUBResource] {
        var resources: [String: EPUBResource] = [:]
        for (id, item) in manifest {
            resources[id] = EPUBResource(
                id: id,
                href: item.href,
                mediaType: item.mediaType,
                properties: item.properties,
                absolutePath: basePath.appendingPathComponent(item.href)
            )
        }
        return resources
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
    
    private static func parseNavigation(manifest: [String: ManifestItem], basePath: URL, spine: [String]) throws -> [TOCItem] {
        if let ncxItem = manifest.first(where: { $0.value.mediaType == "application/x-dtbncx+xml" })?.value {
            let ncxPath = basePath.appendingPathComponent(ncxItem.href)
            return try parseNCXRecursive(at: ncxPath)
        }
        
        if let navItem = manifest.first(where: {
            $0.value.mediaType == "application/xhtml+xml" && $0.value.properties?.contains("nav") == true
        })?.value {
            let navPath = basePath.appendingPathComponent(navItem.href)
            return try parseNavRecursive(at: navPath)
        }
        
        return []
    }
    
    private static func parseNCXRecursive(at url: URL) throws -> [TOCItem] {
        let content = try String(contentsOf: url, encoding: .utf8)
        return parseNCXNavPoints(content: content, parentPattern: "<navMap[^>]*>(.*?)</navMap>")
    }
    
    private static func parseNCXNavPoints(content: String, parentPattern: String) -> [TOCItem] {
        var items: [TOCItem] = []
        
        guard let parentContent = extractFirstMatch(in: content, pattern: parentPattern) else {
            return items
        }
        
        let navPointPattern = "<navPoint[^>]*id=\"([^\"]+)\"[^>]*>(.*?)</navPoint>"
        guard let navPointRegex = try? NSRegularExpression(pattern: navPointPattern, options: [.dotMatchesLineSeparators]) else {
            return items
        }
        
        let navPoints = navPointRegex.matches(in: parentContent, range: NSRange(parentContent.startIndex..., in: parentContent))
        
        for match in navPoints {
            guard let contentRange = Range(match.range(at: 2), in: parentContent) else { continue }
            let navPointContent = String(parentContent[contentRange])
            
            var title: String?
            var href: String?
            var fragmentId: String?
            
            if let textContent = extractFirstMatch(in: navPointContent, pattern: "<text[^>]*>([^<]+)</text>") {
                title = textContent
            }
            
            if let srcContent = extractFirstMatch(in: navPointContent, pattern: "src=\"([^\"]+)\"") {
                href = srcContent.substringBeforeLast("#")
                fragmentId = srcContent.contains("#") ? srcContent.substringAfterLast("#") : nil
            }
            
            let children = parseNCXNavPoints(content: navPointContent, parentPattern: "<navPoint[^>]*>(.*?)</navPoint>")
            
            if let title = title, let href = href {
                items.append(TOCItem(title: title, href: href, fragmentId: fragmentId, level: 1, children: children))
            }
        }
        
        return items
    }
    
    private static func parseNavRecursive(at url: URL) throws -> [TOCItem] {
        let content = try String(contentsOf: url, encoding: .utf8)
        do {
            let doc = try SwiftSoup.parse(content)
            let navElements = try doc.select("nav[epub:type='toc'], nav")
            
            if let navElement = navElements.first() {
                return parseNavList(element: navElement, level: 1)
            }
        } catch {}
        
        return parseNavSimple(content: content)
    }
    
    private static func parseNavList(element: Element, level: Int) -> [TOCItem] {
        var items: [TOCItem] = []
        
        do {
            let listItems = try element.select("li")
            for li in listItems.array() {
                let links = try li.select("a")
                guard let link = links.first() else { continue }
                
                let title = try link.text()
                let href = try link.attr("href")
                let fragmentId = href.contains("#") ? href.substringAfterLast("#") : nil
                let hrefWithoutFragment = href.substringBeforeLast("#")
                
                let nestedLists = try li.select("ol, ul")
                let children: [TOCItem] = nestedLists.first() != nil 
                    ? parseNavList(element: nestedLists.first()!, level: level + 1)
                    : []
                
                items.append(TOCItem(title: title, href: hrefWithoutFragment, fragmentId: fragmentId, level: level, children: children))
            }
        } catch {}
        
        return items
    }
    
    private static func parseNavSimple(content: String) -> [TOCItem] {
        var items: [TOCItem] = []
        
        let linkPattern = "<a[^>]+href=\"([^\"]+)\"[^>]*>([^<]+)</a>"
        guard let linkRegex = try? NSRegularExpression(pattern: linkPattern) else { return items }
        
        let links = linkRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))
        
        for match in links {
            guard let hrefRange = Range(match.range(at: 1), in: content),
                  let titleRange = Range(match.range(at: 2), in: content) else { continue }
            
            let href = String(content[hrefRange])
            let fragmentId = href.contains("#") ? href.substringAfterLast("#") : nil
            let hrefWithoutFragment = href.substringBeforeLast("#")
            
            items.append(TOCItem(title: String(content[titleRange]), href: hrefWithoutFragment, fragmentId: fragmentId, level: 1, children: []))
        }
        
        return items
    }
    
    private static func parseChaptersWithFragmentId(
        spine: [String],
        manifest: [String: ManifestItem],
        toc: [TOCItem],
        basePath: URL,
        epubDir: URL
    ) throws -> [EPUBChapter] {
        var chapters: [EPUBChapter] = []
        
        if toc.isEmpty {
            chapters = try parseChaptersFromSpine(spine: spine, manifest: manifest, basePath: basePath, epubDir: epubDir)
        } else {
            var durIndex = 0
            
            try parseFirstPage(
                chapters: &chapters,
                spine: spine,
                manifest: manifest,
                toc: toc,
                basePath: basePath,
                epubDir: epubDir,
                durIndex: &durIndex
            )
            
            parseMenuRecursive(
                chapters: &chapters,
                tocItems: toc,
                spine: spine,
                manifest: manifest,
                basePath: basePath,
                epubDir: epubDir,
                durIndex: &durIndex,
                level: 0
            )
            
            for i in chapters.indices {
                chapters[i] = EPUBChapter(
                    id: chapters[i].id,
                    title: chapters[i].title,
                    href: chapters[i].href,
                    htmlPath: chapters[i].htmlPath,
                    index: i,
                    mediaType: chapters[i].mediaType,
                    startFragmentId: chapters[i].startFragmentId,
                    endFragmentId: chapters[i].endFragmentId,
                    nextUrl: chapters[i].nextUrl,
                    isVolume: chapters[i].isVolume
                )
            }
        }
        
        return chapters
    }
    
    private static func parseFirstPage(
        chapters: inout [EPUBChapter],
        spine: [String],
        manifest: [String: ManifestItem],
        toc: [TOCItem],
        basePath: URL,
        epubDir: URL,
        durIndex: inout Int
    ) throws {
        guard let firstTocRef = toc.first(where: { !$0.href.isEmpty }) else { return }
        
        let firstTocHref = firstTocRef.href.substringBeforeLast("#")
        
        for (spineIndex, itemId) in spine.enumerated() {
            guard let item = manifest[itemId] else { continue }
            
            if !item.mediaType.contains("htm") && !item.mediaType.contains("html") {
                continue
            }
            
            if item.href == firstTocHref || item.href.hasPrefix(firstTocHref) {
                break
            }
            
            let chapterPath = basePath.appendingPathComponent(item.href)
            var chapterTitle = "--卷首--"
            
            if FileManager.default.fileExists(atPath: chapterPath.path) {
                let htmlContent = try String(contentsOf: chapterPath, encoding: .utf8)
                if let title = extractFirstMatch(in: htmlContent, pattern: "<title[^>]*>([^<]+)</title>"), !title.isEmpty {
                    chapterTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            let relativePath = chapterPath.path.hasPrefix(epubDir.path)
                ? String(chapterPath.path.dropFirst(epubDir.path.count + 1))
                : item.href
            
            let fragmentId = item.href.contains("#") ? item.href.substringAfterLast("#") : nil
            
            let chapter = EPUBChapter(
                id: itemId,
                title: chapterTitle,
                href: item.href,
                htmlPath: relativePath,
                index: durIndex,
                mediaType: item.mediaType,
                startFragmentId: fragmentId,
                endFragmentId: nil,
                nextUrl: nil,
                isVolume: false
            )
            
            if let lastChapter = chapters.last {
                chapters[chapters.count - 1] = EPUBChapter(
                    id: lastChapter.id,
                    title: lastChapter.title,
                    href: lastChapter.href,
                    htmlPath: lastChapter.htmlPath,
                    index: lastChapter.index,
                    mediaType: lastChapter.mediaType,
                    startFragmentId: lastChapter.startFragmentId,
                    endFragmentId: fragmentId,
                    nextUrl: item.href,
                    isVolume: lastChapter.isVolume
                )
            }
            
            chapters.append(chapter)
            durIndex += 1
        }
    }
    
    private static func parseMenuRecursive(
        chapters: inout [EPUBChapter],
        tocItems: [TOCItem],
        spine: [String],
        manifest: [String: ManifestItem],
        basePath: URL,
        epubDir: URL,
        durIndex: inout Int,
        level: Int
    ) {
        for tocItem in tocItems {
            let href = tocItem.href.isEmpty ? tocItem.href : tocItem.href
            let fragmentId = tocItem.fragmentId
            
            let relativePath = href.isEmpty ? "" : {
                let fullPath = basePath.appendingPathComponent(href)
                return fullPath.path.hasPrefix(epubDir.path)
                    ? String(fullPath.path.dropFirst(epubDir.path.count + 1))
                    : href
            }()
            
            let chapter = EPUBChapter(
                id: href,
                title: tocItem.title,
                href: href,
                htmlPath: relativePath,
                index: durIndex,
                mediaType: "application/xhtml+xml",
                startFragmentId: fragmentId,
                endFragmentId: nil,
                nextUrl: nil,
                isVolume: !tocItem.children.isEmpty
            )
            
            if let lastChapter = chapters.last {
                chapters[chapters.count - 1] = EPUBChapter(
                    id: lastChapter.id,
                    title: lastChapter.title,
                    href: lastChapter.href,
                    htmlPath: lastChapter.htmlPath,
                    index: lastChapter.index,
                    mediaType: lastChapter.mediaType,
                    startFragmentId: lastChapter.startFragmentId,
                    endFragmentId: fragmentId,
                    nextUrl: href,
                    isVolume: lastChapter.isVolume
                )
            }
            
            chapters.append(chapter)
            durIndex += 1
            
            if !tocItem.children.isEmpty {
                parseMenuRecursive(
                    chapters: &chapters,
                    tocItems: tocItem.children,
                    spine: spine,
                    manifest: manifest,
                    basePath: basePath,
                    epubDir: epubDir,
                    durIndex: &durIndex,
                    level: level + 1
                )
            }
        }
    }
    
    private static func parseChaptersFromSpine(
        spine: [String],
        manifest: [String: ManifestItem],
        basePath: URL,
        epubDir: URL
    ) throws -> [EPUBChapter] {
        var chapters: [EPUBChapter] = []
        
        for (index, itemId) in spine.enumerated() {
            guard let item = manifest[itemId] else { continue }
            
            let chapterPath = basePath.appendingPathComponent(item.href)
            var chapterTitle = index == 0 ? "封面" : "第 \(index + 1) 章"
            
            if FileManager.default.fileExists(atPath: chapterPath.path) {
                let htmlContent = try String(contentsOf: chapterPath, encoding: .utf8)
                
                if let title = extractFirstMatch(in: htmlContent, pattern: "<title[^>]*>([^<]+)</title>"), !title.isEmpty {
                    chapterTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                } else if let h1 = extractFirstMatch(in: htmlContent, pattern: "<h1[^>]*>([^<]+)</h1>") {
                    chapterTitle = h1.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            let relativePath = chapterPath.path.hasPrefix(epubDir.path)
                ? String(chapterPath.path.dropFirst(epubDir.path.count + 1))
                : item.href
            
            var nextUrl: String? = nil
            if index < spine.count - 1, let nextItem = manifest[spine[index + 1]] {
                nextUrl = nextItem.href
            }
            
            chapters.append(EPUBChapter(
                id: itemId,
                title: chapterTitle,
                href: item.href,
                htmlPath: relativePath,
                index: index,
                mediaType: item.mediaType,
                startFragmentId: nil,
                endFragmentId: nil,
                nextUrl: nextUrl,
                isVolume: false
            ))
        }
        
        return chapters
    }
    
    static func getChapterContent(
        book: EPUBBook,
        chapter: EPUBChapter,
        delRubyTag: Bool = false,
        delHTag: Bool = false
    ) throws -> String {
        let contents = buildContentsList(book: book)
        
        let nextChapterHref = chapter.nextUrl?.substringBeforeLast("#") ?? ""
        let currentChapterHref = chapter.href.substringBeforeLast("#")
        let isLastChapter = nextChapterHref.isEmpty
        let startFragmentId = chapter.startFragmentId
        let endFragmentId = chapter.endFragmentId
        
        var elements: [Element] = []
        var foundFirstResource = false
        let includeNextChapterResource = endFragmentId != nil && !endFragmentId!.isEmpty
        
        for resource in contents {
            if !foundFirstResource {
                if currentChapterHref != resource.href { continue }
                foundFirstResource = true
                elements.append(
                    getBody(
                        resource: resource,
                        startFragmentId: startFragmentId,
                        endFragmentId: endFragmentId,
                        delRubyTag: delRubyTag,
                        delHTag: delHTag,
                        epubDir: book.epubDirectory
                    )
                )
                if !isLastChapter && resource.href == nextChapterHref { break }
                continue
            }
            
            if nextChapterHref != resource.href {
                elements.append(
                    getBody(
                        resource: resource,
                        startFragmentId: nil,
                        endFragmentId: nil,
                        delRubyTag: delRubyTag,
                        delHTag: delHTag,
                        epubDir: book.epubDirectory
                    )
                )
            } else {
                if includeNextChapterResource {
                    elements.append(
                        getBody(
                            resource: resource,
                            startFragmentId: nil,
                            endFragmentId: endFragmentId,
                            delRubyTag: delRubyTag,
                            delHTag: delHTag,
                            epubDir: book.epubDirectory
                        )
                    )
                }
                break
            }
        }
        
        let combinedElements = Elements(elements)
        do {
            try combinedElements.select("title").remove()
            try combinedElements.select("[style*=display:none]").remove()
            
            let coverImgs = try combinedElements.select("img[src=\"cover.jpeg\"]").array()
            for (index, img) in coverImgs.enumerated() {
                if index > 0 { try img.remove() }
            }
            
            let imgs = try combinedElements.select("img").array()
            for img in imgs {
                let src = try img.attr("src")
                try img.attr("src", src)
            }
            
            if delRubyTag {
                try combinedElements.select("rp, rt").remove()
            }
            
            if delHTag {
                try combinedElements.select("h1, h2, h3, h4, h5, h6").remove()
            }
        } catch {}
        
        let html = elements.compactMap { try? $0.outerHtml() }.joined()
        return HTMLToTextConverter.formatKeepImg(html: html, baseURL: book.epubDirectory)
    }
    
    private static func buildContentsList(book: EPUBBook) -> [EPUBResource] {
        var contents: [EPUBResource] = []
        for itemId in book.spine {
            if let resource = book.resources[itemId] {
                contents.append(resource)
            }
        }
        return contents
    }
    
    private static func getBody(
        resource: EPUBResource,
        startFragmentId: String?,
        endFragmentId: String?,
        delRubyTag: Bool,
        delHTag: Bool,
        epubDir: URL
    ) -> Element {
        if resource.href.contains("titlepage.xhtml") || resource.href.contains("cover") {
            do {
                if let body = try SwiftSoup.parseBodyFragment("<img src=\"cover.jpeg\" />").body() {
                    return body
                }
            } catch {}
            return createEmptyBody()
        }
        
        guard FileManager.default.fileExists(atPath: resource.absolutePath.path) else {
            do {
                if let body = try SwiftSoup.parseBodyFragment("").body() {
                    return body
                }
            } catch {}
            return createEmptyBody()
        }
        
        do {
            let htmlContent = try String(contentsOf: resource.absolutePath, encoding: .utf8)
            let doc = try SwiftSoup.parse(htmlContent)
            guard var bodyElement = try doc.body() else {
                return createEmptyBody()
            }
            
            try bodyElement.select("script").remove()
            try bodyElement.select("style").remove()
            
            var bodyString = try bodyElement.outerHtml()
            let originalBodyString = bodyString
            
            if let startId = startFragmentId, !startId.isEmpty {
                if let startElement = try bodyElement.getElementById(startId) {
                    let startOuterHtml = try startElement.outerHtml()
                    let tagStart = startOuterHtml.substringBefore("\n")
                    if let range = bodyString.range(of: tagStart) {
                        bodyString = tagStart + bodyString.substring(from: range.upperBound)
                    }
                }
            }
            
            if let endId = endFragmentId, !endId.isEmpty, endId != startFragmentId {
                if let endElement = try bodyElement.getElementById(endId) {
                    let endOuterHtml = try endElement.outerHtml()
                    let tagStart = endOuterHtml.substringBefore("\n")
                    if let range = bodyString.range(of: tagStart) {
                        bodyString = bodyString.substring(to: range.lowerBound)
                    }
                }
            }
            
            if bodyString != originalBodyString {
                let newDoc = try SwiftSoup.parse(bodyString)
                if let newBody = try newDoc.body() {
                    bodyElement = newBody
                }
            }
            
            if delHTag {
                try bodyElement.select("h1, h2, h3, h4, h5, h6").remove()
            }
            
            let imageElements = try bodyElement.select("image").array()
            for imageEl in imageElements {
                try imageEl.tagName("img")
                let xlinkHref = try imageEl.attr("xlink:href")
                if !xlinkHref.isEmpty {
                    try imageEl.attr("src", xlinkHref)
                }
            }
            
            let imgElements = try bodyElement.select("img").array()
            for imgEl in imgElements {
                let src = try imgEl.attr("src").trimmingCharacters(in: .whitespaces)
                let encodedSrc = src.encodeURI()
                let href = resource.href.encodeURI()
                let resolvedHref = URL(string: href)?.appendingPathComponent(encodedSrc).absoluteString ?? src
                try imgEl.attr("src", resolvedHref)
            }
            
            return bodyElement
            
        } catch {
            return createEmptyBody()
        }
    }
    
    private static func createEmptyBody() -> Element {
        let doc = try! SwiftSoup.parse("<body></body>")
        return try! doc.body()!
    }
    
    static func getImage(book: EPUBBook, href: String) -> Data? {
        if href == "cover.jpeg" {
            return book.coverImage
        }
        
        let decodedHref = href.removingPercentEncoding ?? href
        
        for (_, resource) in book.resources {
            if resource.href == decodedHref || resource.absolutePath.path.contains(decodedHref) {
                return try? Data(contentsOf: resource.absolutePath)
            }
        }
        
        let imagePath = book.opfBasePath.appendingPathComponent(decodedHref)
        return try? Data(contentsOf: imagePath)
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

fileprivate struct ManifestItem {
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
    case resourceNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound: return "EPUB 文件不存在"
        case .invalidFormat: return "无效的 EPUB 格式"
        case .parseFailed(let reason): return "解析失败：\(reason)"
        case .chapterNotFound: return "章节不存在"
        case .resourceNotFound(let href): return "资源不存在：\(href)"
        }
    }
}

extension String {
    func substringBeforeLast(_ separator: String) -> String {
        if let range = self.range(of: separator, options: .backwards) {
            return String(self[self.startIndex..<range.lowerBound])
        }
        return self
    }
    
    func substringAfterLast(_ separator: String) -> String {
        if let range = self.range(of: separator, options: .backwards) {
            return String(self[range.upperBound..<self.endIndex])
        }
        return self
    }
    
    func substringBefore(_ separator: String) -> String {
        if let range = self.range(of: separator) {
            return String(self[self.startIndex..<range.lowerBound])
        }
        return self
    }
    
    func substring(from index: String.Index) -> String {
        return String(self[index..<self.endIndex])
    }
    
    func substring(to index: String.Index) -> String {
        return String(self[self.startIndex..<index])
    }
    
    func encodeURI() -> String {
        return self.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? self
    }
}
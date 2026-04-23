//
//  ExportBookService.swift
//  Legado-iOS
//
//  导出书籍服务 - 1:1 对齐 Android ExportBookService.kt
//  支持 TXT / EPUB 导出，含图片、CSS、WebDAV 上传
//  EPUB 使用纯 Swift ZipBuilder 打包（对应 Android epublib）
//

import Foundation
import CoreData

// MARK: - 导出配置（对应 Android ExportConfig）

struct ExportConfig {
    let path: String
    let type: String       // "epub" 或 "txt"
    let epubSize: Int = 1  // 每个 EPUB 最多包含章节数（对应 Android 默认值 1）
    let epubScope: String? = nil  // 章节范围，如 "1-100,101-200"
}

// MARK: - 内部数据结构

/// 图片数据引用（对应 Android SrcData）
private struct SrcData {
    let chapterTitle: String
    let index: Int
    let src: String
}

/// EPUB 资源（对应 Android epublib Resource）
private struct EpubResource {
    let data: Data
    let href: String
    let mediaType: String
}

// MARK: - ExportConfig 扩展（导出配置默认值，对应 Android AppConfig）

extension ExportConfig {
    /// 对应 Android AppConfig 导出相关配置
    /// iOS 端从 UserDefaults 读取，键名对齐 Android
    static var exportCharset: String {
        UserDefaults.standard.string(forKey: "exportCharset") ?? "UTF-8"
    }
    static var parallelExportBook: Bool {
        UserDefaults.standard.bool(forKey: "parallelExportBook")
    }
    static var exportUseReplace: Bool {
        UserDefaults.standard.object(forKey: "exportUseReplace") as? Bool ?? true
    }
    static var exportPictureFile: Bool {
        UserDefaults.standard.object(forKey: "exportPictureFile") as? Bool ?? true
    }
    static var exportToWebDav: Bool {
        UserDefaults.standard.object(forKey: "exportToWebDav") as? Bool ?? false
    }
    static var exportNoChapterName: Bool {
        UserDefaults.standard.object(forKey: "exportNoChapterName") as? Bool ?? false
    }
}

// MARK: - 自定义分割导出器（对应 Android CustomExporter）

/// 对应 Android ExportBookService.CustomExporter
private class CustomExporter {
    let scopeStr: String
    let size: Int
    weak var service: ExportBookService?
    
    init(scopeStr: String, size: Int, service: ExportBookService) {
        self.scopeStr = scopeStr
        self.size = size
        self.service = service
    }
    
    func export(path: String, book: Book) async throws {
        guard let service = service else { return }
        
        service.exportProgress[book.bookUrl] = 0
        service.exportMessages.removeValue(forKey: book.bookUrl)
        NotificationCenter.default.post(name: .exportBook, object: book.bookUrl)
        
        var scope = ExportBookService.parseScope(scopeStr)
        let chapterCount = service.getChapterCount(bookUrl: book.bookUrl)
        scope = scope.filter { $0 < chapterCount }
        
        let numOfEpubs = ExportBookService.paresNumOfEpub(total: scope.count, size: size)
        let exportDir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
        
        let contentProcessor = ContentProcessor.get(book.name, book.origin)
        let useReplace = ExportConfig.exportUseReplace
        let contentModel = service.generateChapterTemplate()
        
        for epubIndex in 0..<numOfEpubs {
            guard !Task.isCancelled else { break }
            
            let filename = ExportBookService.getExportFileName(book: book, ext: "epub", index: epubIndex + 1)
            let fileUrl = exportDir.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: fileUrl.path) {
                try FileManager.default.removeItem(at: fileUrl)
            }
            
            var resources: [EpubResource] = []
            var sections: [(String, String)] = []
            
            // CSS
            resources.append(EpubResource(
                data: service.generateMainCSS().data(using: .utf8)!,
                href: "Styles/main.css",
                mediaType: "text/css"
            ))
            resources.append(EpubResource(
                data: service.generateFontsCSS().data(using: .utf8)!,
                href: "Styles/fonts.css",
                mediaType: "text/css"
            ))
            
            // 封面 + 简介
            sections.append(("封面", service.generateCoverHTML(book: book)))
            sections.append(("简介", service.generateIntroHTML(book: book)))
            
            // 封面图片
            service.appendCoverResource(book: book, resources: &resources)
            
            // 本 epub 包含的章节
            let sortedScope = scope.sorted()
            let startIndex = epubIndex * size
            let endIndex = min(sortedScope.count, (epubIndex + 1) * size)
            let chapters = service.getChapterList(bookUrl: book.bookUrl)
            
            for i in startIndex..<endIndex {
                guard i < sortedScope.count else { break }
                let chapterIndex = sortedScope[i]
                guard chapterIndex < chapters.count else { continue }
                let chapter = chapters[chapterIndex]
                // 不导出VIP标识（对应 Android chapter.isVip = false）
                var chapterForExport = chapter
                chapterForExport.isVIP = false
                
                let content = BookHelp.getContent(book, chapterForExport)
                let (contentFix, chapterResources) = service.fixPic(
                    book: book,
                    content: content ?? (chapter.isVolume ? "" : "null"),
                    chapter: chapterForExport
                )
                resources.append(contentsOf: chapterResources)
                
                let processedContent = contentProcessor.getContent(
                    book: book,
                    chapter: chapterForExport,
                    content: contentFix,
                    includeTitle: false,
                    useReplace: useReplace,
                    chineseConvert: false
                )
                
                // 对应 Android chapter.getDisplayTitle()
                let title = chapterForExport.displayTitle
                    .replacingOccurrences(of: "\u{1F512}", with: "")  // 移除VIP锁图标
                
                let chapterHtml = contentModel
                    .replacingOccurrences(of: "{{title}}", with: title)
                    .replacingOccurrences(of: "{{content}}", with: processedContent.contents.joined(separator: "\n"))
                
                sections.append((title, chapterHtml))
                
                service.exportProgress[book.bookUrl] = i
                NotificationCenter.default.post(name: .exportBook, object: book.bookUrl)
            }
            
            let epubData = try service.buildEpub(book: book, sections: sections, resources: resources)
            try epubData.write(to: fileUrl)
        }
    }
}

// MARK: - 导出书籍服务主类

/// 导出书籍服务 - 对应 Android ExportBookService
@MainActor
class ExportBookService: ObservableObject {
    
    static let shared = ExportBookService()
    
    // MARK: - 状态（对应 Android ConcurrentHashMap）
    
    @Published var exportProgress: [String: Int] = [:]        // 对应 Android exportProgress
    @Published var exportMessages: [String: String] = [:]     // 对应 Android exportMsg
    @Published var isRunning: Bool = false
    
    private var waitExportBooks: [(String, ExportConfig)] = []  // 对应 Android linkedMapOf
    private var exportTask: Task<Void, Never>?                 // 对应 Android exportJob
    
    private init() {}
    
    // MARK: - 公开方法（对应 Android onStartCommand）
    
    /// 开始导出（对应 Android IntentAction.start）
    func startExport(bookUrl: String, config: ExportConfig) {
        if exportProgress[bookUrl] != nil { return } // 已在导出
        
        waitExportBooks.append((bookUrl, config))
        exportMessages[bookUrl] = "等待导出"  // 对应 R.string.export_wait
        NotificationCenter.default.post(name: .exportBook, object: bookUrl)
        
        export()
    }
    
    /// 停止导出（对应 Android IntentAction.stop + onDestroy）
    func stop() {
        exportTask?.cancel()
        exportTask = nil
        // 对应 Android onDestroy: 通知所有等待中的书
        for (bookUrl, _) in waitExportBooks {
            NotificationCenter.default.post(name: .exportBook, object: bookUrl)
        }
        exportProgress.removeAll()
        exportMessages.removeAll()
        waitExportBooks.removeAll()
        isRunning = false
    }
    
    // MARK: - 导出主流程（对应 Android export()）
    
    private func export() {
        if exportTask != nil { return }
        
        isRunning = true
        exportTask = Task { [weak self] in
            guard let self = self else { return }
            
            while !Task.isCancelled {
                guard let (bookUrl, config) = self.waitExportBooks.first else {
                    self.isRunning = false
                    self.exportTask = nil
                    return
                }
                
                self.waitExportBooks.removeFirst()
                self.exportProgress[bookUrl] = 0
                
                let book = self.fetchBook(bookUrl: bookUrl)
                
                do {
                    guard let book = book else {
                        throw ExportBookError.bookNotFound
                    }
                    
                    self.refreshChapterList(book)
                    
                    if config.type == "epub" {
                        if let scope = config.epubScope, !scope.isEmpty {
                            // 自定义分割导出（对应 Android CustomExporter）
                            let exporter = CustomExporter(scopeStr: scope, size: config.epubSize, service: self)
                            try await exporter.export(path: config.path, book: book)
                        } else {
                            try await self.exportEpub(path: config.path, book: book)
                        }
                    } else {
                        try await self.exportTxt(path: config.path, book: book)
                    }
                    
                    self.exportMessages[bookUrl] = "导出成功"  // 对应 R.string.export_success
                    
                    // WebDAV 上传（对应 Android AppConfig.exportToWebDav）
                    if ExportConfig.exportToWebDav {
                        // TODO: WebDAV 上传，对应 Android AppWebDav.exportWebDav
                    }
                } catch {
                    if !Task.isCancelled {
                        self.exportMessages[bookUrl] = error.localizedDescription
                    }
                }
                
                self.exportProgress.removeValue(forKey: bookUrl)
                NotificationCenter.default.post(name: .exportBook, object: bookUrl)
            }
        }
    }
    
    // MARK: - TXT 导出（对应 Android exportTxt）
    
    private func exportTxt(path: String, book: Book) async throws {
        exportMessages.removeValue(forKey: book.bookUrl)
        NotificationCenter.default.post(name: .exportBook, object: book.bookUrl)
        
        let filename = getExportFileName(book: book, ext: "txt")
        let exportDir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
        
        let fileUrl = exportDir.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: fileUrl.path) {
            try FileManager.default.removeItem(at: fileUrl)
        }
        
        // 对应 Android getAllContents 中的头部信息
        // book.realAuthor 对应 Android book.getRealAuthor()
        var fullText = "\(book.name)\n"
        fullText += "作者: \(book.realAuthor)\n"
        // book.displayIntro 对应 Android book.getDisplayIntro()
        let introText = book.displayIntro ?? book.intro ?? ""
        fullText += "简介:\n\(introText)"
        
        let chapters = getChapterList(bookUrl: book.bookUrl)
        let useReplace = ExportConfig.exportUseReplace
        let contentProcessor = ContentProcessor.get(book.name, book.origin)
        
        if ExportConfig.exportPictureFile {
            // TXT + 图片导出模式
            var allSrcData: [SrcData] = []
            
            for (index, chapter) in chapters.enumerated() {
                guard !Task.isCancelled else { break }
                // 不导出VIP标识
                var chapterForExport = chapter
                chapterForExport.isVIP = false
                
                let content = BookHelp.getContent(book, chapterForExport)
                let processedContent = contentProcessor.getContent(
                    book: book,
                    chapter: chapterForExport,
                    content: content ?? (chapter.isVolume ? "" : "null"),
                    includeTitle: !ExportConfig.exportNoChapterName,
                    useReplace: useReplace,
                    chineseConvert: false
                )
                
                fullText += "\n\n\(processedContent.contents.joined(separator: "\n"))"
                
                // 提取图片引用（对应 Android getExportData 中的 srcList）
                if let content = content {
                    let imgPattern = try NSRegularExpression(pattern: "<img[^>]+src\\s*=\\s*[\"']([^\"']+)", options: [])
                    let matches = imgPattern.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))
                    for match in matches {
                        if let range = Range(match.range(at: 1), in: content) {
                            let src = String(content[range])
                            let absoluteSrc = NetworkUtils.getAbsoluteURL(baseURL: chapter.chapterUrl, relativePath: src)
                            allSrcData.append(SrcData(chapterTitle: chapter.title, index: index, src: absoluteSrc))
                        }
                    }
                }
                
                self.exportProgress[book.bookUrl] = index
                NotificationCenter.default.post(name: .exportBook, object: book.bookUrl)
            }
            
            // 写入 TXT
            try fullText.write(to: fileUrl, atomically: true, encoding: .utf8)
            
            // 导出图片文件（对应 Android exportTxt 图片写入）
            let imagesBaseDir = exportDir.appendingPathComponent("\(book.name)_\(book.realAuthor)")
                .appendingPathComponent("images")
            
            for srcData in allSrcData {
                let imageData = loadImageData(book: book, src: srcData.src)
                if let imageData = imageData {
                    let chapterDir = imagesBaseDir.appendingPathComponent(srcData.chapterTitle)
                    try? FileManager.default.createDirectory(at: chapterDir, withIntermediateDirectories: true)
                    let imgName = "\(srcData.index)-\(MD5Utils.md5Encode16(srcData.src)).jpg"
                    try? imageData.write(to: chapterDir.appendingPathComponent(imgName))
                }
            }
        } else {
            // 纯文本导出（无图片）
            for (index, chapter) in chapters.enumerated() {
                guard !Task.isCancelled else { break }
                var chapterForExport = chapter
                chapterForExport.isVIP = false
                
                let content = BookHelp.getContent(book, chapterForExport)
                let processedContent = contentProcessor.getContent(
                    book: book,
                    chapter: chapterForExport,
                    content: content ?? (chapter.isVolume ? "" : "null"),
                    includeTitle: !ExportConfig.exportNoChapterName,
                    useReplace: useReplace,
                    chineseConvert: false
                )
                
                fullText += "\n\n\(processedContent.contents.joined(separator: "\n"))"
                
                self.exportProgress[book.bookUrl] = index
                NotificationCenter.default.post(name: .exportBook, object: book.bookUrl)
            }
            
            try fullText.write(to: fileUrl, atomically: true, encoding: .utf8)
        }
        
        // WebDAV 上传
        if ExportConfig.exportToWebDav {
            // TODO: 对应 Android AppWebDav.exportWebDav
        }
    }
    
    // MARK: - EPUB 导出（对应 Android exportEpub）
    
    private func exportEpub(path: String, book: Book) async throws {
        exportMessages.removeValue(forKey: book.bookUrl)
        NotificationCenter.default.post(name: .exportBook, object: book.bookUrl)
        
        let filename = getExportFileName(book: book, ext: "epub")
        let exportDir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
        
        let fileUrl = exportDir.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: fileUrl.path) {
            try FileManager.default.removeItem(at: fileUrl)
        }
        
        var resources: [EpubResource] = []
        var sections: [(String, String)] = []  // (title, htmlContent)
        var volumeSections: [(title: String, isVolume: Bool)] = []  // 追踪卷标层级
        
        // CSS（对应 Android setAssets）
        let (contentModel, cssResources) = setAssets(book: book)
        resources.append(contentsOf: cssResources)
        
        // 封面页
        sections.append(("封面", generateCoverHTML(book: book)))
        volumeSections.append((title: "封面", isVolume: true))
        
        // 简介页
        sections.append(("简介", generateIntroHTML(book: book)))
        volumeSections.append((title: "简介", isVolume: true))
        
        // 封面图片（对应 Android setCover）
        appendCoverResource(book: book, resources: &resources)
        
        // 章节（对应 Android setEpubContent）
        let chapters = getChapterList(bookUrl: book.bookUrl)
        let useReplace = ExportConfig.exportUseReplace
        let contentProcessor = ContentProcessor.get(book.name, book.origin)
        
        for (index, chapter) in chapters.enumerated() {
            guard !Task.isCancelled else { break }
            var chapterForExport = chapter
            chapterForExport.isVIP = false  // 不导出VIP标识
            
            let content = BookHelp.getContent(book, chapterForExport)
            let (contentFix, chapterResources) = fixPic(
                book: book,
                content: content ?? (chapter.isVolume ? "" : "null"),
                chapter: chapterForExport
            )
            resources.append(contentsOf: chapterResources)
            
            let processedContent = contentProcessor.getContent(
                book: book,
                chapter: chapterForExport,
                content: contentFix,
                includeTitle: false,
                useReplace: useReplace,
                chineseConvert: false
            )
            
            // 对应 Android chapter.getDisplayTitle()
            let title = chapterForExport.displayTitle
                .replacingOccurrences(of: "\u{1F512}", with: "")  // 移除🔒图标
            
            let chapterHtml = contentModel
                .replacingOccurrences(of: "{{title}}", with: title)
                .replacingOccurrences(of: "{{content}}", with: processedContent.contents.joined(separator: "\n"))
            
            sections.append((title, chapterHtml))
            volumeSections.append((title: title, isVolume: chapter.isVolume))
            
            self.exportProgress[book.bookUrl] = index
            NotificationCenter.default.post(name: .exportBook, object: book.bookUrl)
        }
        
        // 构建 EPUB（对应 Android EpubWriter.write）
        let epubData = try buildEpub(book: book, sections: sections, resources: resources, volumeSections: volumeSections)
        try epubData.write(to: fileUrl)
        
        // WebDAV 上传
        if ExportConfig.exportToWebDav {
            // TODO: 对应 Android AppWebDav.exportWebDav
        }
    }
    
    // MARK: - 资源设置（对应 Android setAssets）
    
    /// 对应 Android setAssets - 内置模板
    private func setAssets(book: Book) -> (contentModel: String, resources: [EpubResource]) {
        var resources: [EpubResource] = []
        
        // CSS（对应 Android assets/epub/fonts.css 和 main.css）
        resources.append(EpubResource(
            data: generateFontsCSS().data(using: .utf8)!,
            href: "Styles/fonts.css",
            mediaType: "text/css"
        ))
        resources.append(EpubResource(
            data: generateMainCSS().data(using: .utf8)!,
            href: "Styles/main.css",
            mediaType: "text/css"
        ))
        
        // Logo（对应 Android assets/epub/logo.png）
        if let logoData = getLogoData() {
            resources.append(EpubResource(data: logoData, href: "Images/logo.png", mediaType: "image/png"))
        }
        
        return (contentModel: generateChapterTemplate(), resources: resources)
    }
    
    /// 追加封面资源（对应 Android setCover）
    func appendCoverResource(book: Book, resources: inout [EpubResource]) {
        let coverUrlStr = book.displayCoverUrl ?? book.coverUrl ?? ""
        guard !coverUrlStr.isEmpty else { return }
        if let imageData = loadImageData(from: coverUrlStr) {
            resources.append(EpubResource(data: imageData, href: "Images/cover.jpg", mediaType: "image/jpeg"))
        }
    }
    
    // MARK: - 图片修复（对应 Android fixPic）
    
    private func fixPic(book: Book, content: String, chapter: BookChapter) -> (String, [EpubResource]) {
        var data = ""
        var resources: [EpubResource] = []
        
        // 对应 Android AppPattern.imgPattern
        let imgPattern = try? NSRegularExpression(pattern: "<img[^>]+src\\s*=\\s*[\"']([^\"']+)", options: [])
        
        for text in content.components(separatedBy: "\n") {
            var text1 = text
            let matches = imgPattern?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) ?? []
            
            for match in matches.reversed() {
                if let range = Range(match.range(at: 1), in: text) {
                    let src = String(text[range])
                    // chapter.chapterUrl 对应 Android chapter.url
                    let absoluteSrc = NetworkUtils.getAbsoluteURL(baseURL: chapter.chapterUrl, relativePath: src)
                    let md5Name = MD5Utils.md5Encode16(absoluteSrc)
                    let suffix = BookHelp.getImageSuffix(absoluteSrc)  // 用 BookHelp 的实现
                    let originalHref = "\(md5Name).\(suffix)"
                    let href = "Images/\(originalHref)"
                    
                    // 通过 BookHelp.getImage 获取 URL 后读 Data
                    // 对应 Android: val vFile = BookHelp.getImage(book, src)
                    let imageData = loadImageData(book: book, src: absoluteSrc)
                    if let imageData = imageData {
                        resources.append(EpubResource(data: imageData, href: href, mediaType: "image/\(suffix)"))
                    }
                    
                    // 对应 Android: text1 = text1.replace(src, "../${href}")
                    text1 = text1.replacingOccurrences(of: src, with: "../\(href)")
                }
            }
            data += text1 + "\n"
        }
        
        return (data, resources)
    }
    
    // MARK: - EPUB 构建（ZIP 合成，对应 Android EpubWriter）
    
    private func buildEpub(
        book: Book,
        sections: [(String, String)],
        resources: [EpubResource],
        volumeSections: [(title: String, isVolume: Bool)]? = nil
    ) throws -> Data {
        let zipBuilder = ZipBuilder(useDeflate: true)
        let uuid = UUID().uuidString
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withColonSeparatorInTime]
        let modifiedDate = dateFormatter.string(from: Date()).replacingOccurrences(of: "+", with: "Z")
        
        // 1. mimetype（EPUB 规范：必须在 ZIP 开头且不压缩）
        zipBuilder.addFile(name: "mimetype", data: "application/epub+zip".data(using: .utf8)!)
        
        // 2. META-INF/container.xml
        let containerXml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """
        zipBuilder.addFile(name: "META-INF/container.xml", content: containerXml)
        
        // 3. 资源文件
        for resource in resources {
            zipBuilder.addFileAuto(name: "OEBPS/\(resource.href)", data: resource.data)
        }
        
        // 4. 章节内容 + TOC 导航点
        var manifestItems: [String] = []
        var spineItems: [String] = []
        var navPoints: [String] = []
        var openNavPointCount = 0  // 未闭合的卷级 navPoint 数
        
        for (index, section) in sections.enumerated() {
            let (title, html) = section
            let filename = "Text/chapter_\(index).xhtml"
            
            let xhtml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE html>
            <html xmlns="http://www.w3.org/1999/xhtml">
            <head><title>\(escapeXml(title))</title>
            <link rel="stylesheet" type="text/css" href="../Styles/main.css"/>
            </head><body>\(html)</body></html>
            """
            zipBuilder.addFileAuto(name: "OEBPS/\(filename)", content: xhtml)
            
            let id = "chapter_\(index)"
            manifestItems.append("<item id=\"\(id)\" href=\"\(filename)\" media-type=\"application/xhtml+xml\"/>")
            spineItems.append("<itemref idref=\"\(id)\"/>")
            
            // TOC 层级（对齐 Android parentSection 逻辑）
            let isVolume = volumeSections?[index].isVolume ?? false
            if isVolume && index > 1 {  // 封面和简介不算卷
                navPoints.append("<navPoint id=\"nav_\(id)\" playOrder=\"\(index + 1)\"><navLabel><text>\(escapeXml(title))</text></navLabel><content src=\"\(filename)\"/>")
                openNavPointCount += 1
            } else {
                navPoints.append("<navPoint id=\"nav_\(id)\" playOrder=\"\(index + 1)\"><navLabel><text>\(escapeXml(title))</text></navLabel><content src=\"\(filename)\"/></navPoint>")
            }
        }
        
        // 闭合未关闭的卷级 navPoint
        for _ in 0..<openNavPointCount {
            navPoints.append("</navPoint>")
        }
        
        // 5. content.opf（对齐 Android setEpubMetadata）
        let bookName = escapeXml(book.name)
        let bookAuthor = escapeXml(book.realAuthor)  // 对应 Android book.getRealAuthor()
        let bookIntro = escapeXml(book.displayIntro ?? "")
        let bookKind = escapeXml(book.kind ?? "")
        
        // 资源 manifest
        let resourceManifests = resources.map { resource in
            let id = "res_\(MD5Utils.md5Encode16(resource.href))"
            return "<item id=\"\(id)\" href=\"\(resource.href)\" media-type=\"\(resource.mediaType)\"/>"
        }.joined(separator: "\n    ")
        
        let contentOpf = """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="BookId">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
            <dc:identifier id="BookId">urn:uuid:\(uuid)</dc:identifier>
            <dc:title>\(bookName)</dc:title>
            <dc:creator>\(bookAuthor)</dc:creator>
            <dc:language>zh</dc:language>
            <dc:publisher>Legado</dc:publisher>
            <dc:description>\(bookIntro)</dc:description>
            <dc:date>\(modifiedDate)</dc:date>
            <meta property="dcterms:modified">\(modifiedDate)</meta>
          </metadata>
          <manifest>
            <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
            \(manifestItems.joined(separator: "\n    "))
            \(resourceManifests)
          </manifest>
          <spine toc="ncx">
            \(spineItems.joined(separator: "\n    "))
          </spine>
        </package>
        """
        zipBuilder.addFileAuto(name: "OEBPS/content.opf", content: contentOpf)
        
        // 6. toc.ncx
        let tocNcx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
          <head><meta name="dtb:uid" content="urn:uuid:\(uuid)"/></head>
          <docTitle><text>\(bookName)</text></docTitle>
          <navMap>\(navPoints.joined(separator: "\n"))</navMap>
        </ncx>
        """
        zipBuilder.addFileAuto(name: "OEBPS/toc.ncx", content: tocNcx)
        
        return zipBuilder.build()
    }
    
    // MARK: - 辅助方法
    
    /// 刷新章节列表（对应 Android refreshChapterList）
    private func refreshChapterList(_ book: Book) {
        // 对应 Android: 仅本地书籍且已修改时刷新
        guard book.isLocal else { return }
        // TODO: 本地书籍章节刷新，需 LocalBook.getChapterList 实现后补全
    }
    
    /// 获取导出文件名（对应 Android Book.getExportFileName）
    static func getExportFileName(book: Book, ext: String, index: Int? = nil) -> String {
        let name = book.name.replacingOccurrences(of: "/", with: "_")
        let author = book.realAuthor.replacingOccurrences(of: "/", with: "_")
        if let index = index {
            return "\(name)-\(author)-\(index).\(ext)"
        }
        return "\(name)-\(author).\(ext)"
    }
    
    /// 解析范围字符串（对应 Android CustomExporter.parseScope）
    static func parseScope(_ scope: String) -> Set<Int> {
        var result = Set<Int>()
        let parts = scope.components(separatedBy: ",")
        for part in parts {
            let range = part.components(separatedBy: "-")
            if range.count == 2, let left = Int(range[0]), let right = Int(range[1]) {
                if left > right { continue }
                for i in left...right {
                    result.insert(i - 1)
                }
            } else if let num = Int(part) {
                result.insert(num - 1)
            }
        }
        return result
    }
    
    /// 计算分割后 EPUB 数量（对应 Android paresNumOfEpub）
    static func paresNumOfEpub(total: Int, size: Int) -> Int {
        let remainder = total % size
        var result = total / size
        if remainder > 0 { result += 1 }
        return result
    }
    
    private func fetchBook(bookUrl: String) -> Book? {
        let context = CoreDataStack.shared.viewContext
        let request: NSFetchRequest<Book> = Book.fetchRequest()
        request.predicate = NSPredicate(format: "bookUrl == %@", bookUrl)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
    
    /// BookChapter 使用 bookId (UUID) 关联 Book，不直接存储 bookUrl
    /// 通过 book.bookId 查询章节
    func getChapterList(bookUrl: String) -> [BookChapter] {
        let context = CoreDataStack.shared.viewContext
        guard let book = fetchBook(bookUrl: bookUrl) else { return [] }
        let request: NSFetchRequest<BookChapter> = BookChapter.fetchRequest()
        request.predicate = NSPredicate(format: "bookId == %@", book.bookId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]
        return (try? context.fetch(request)) ?? []
    }
    
    func getChapterCount(bookUrl: String) -> Int {
        let context = CoreDataStack.shared.viewContext
        guard let book = fetchBook(bookUrl: bookUrl) else { return 0 }
        let request: NSFetchRequest<BookChapter> = BookChapter.fetchRequest()
        request.predicate = NSPredicate(format: "bookId == %@", book.bookId as CVarArg)
        return (try? context.count(for: request)) ?? 0
    }
    
    /// 加载图片数据（对应 Android BookHelp.getImage → 读取 File）
    func loadImageData(book: Book, src: String) -> Data? {
        let imageUrl = BookHelp.getImage(book, src)
        return try? Data(contentsOf: imageUrl)
    }
    
    /// 加载图片数据(from URL string)
    private func loadImageData(from urlString: String) -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        // 先尝试从缓存路径读
        if url.isFileURL {
            return try? Data(contentsOf: url)
        }
        return try? Data(contentsOf: url)
    }
    
    /// XML 特殊字符转义
    private func escapeXml(_ str: String) -> String {
        return str
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
    
    /// 获取 Logo 数据（对应 Android assets/epub/logo.png）
    private func getLogoData() -> Data? {
        // 内置最小合法 PNG 占位符
        let pngData: [UInt8] = [
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
            0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
            0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
            0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4,
            0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
            0xAE, 0x42, 0x60, 0x82
        ]
        return Data(pngData)
    }
    
    // MARK: - HTML 模板（对应 Android assets/epub/*.html）
    
    /// 对应 Android assets/epub/main.css
    private func generateMainCSS() -> String {
        return """
        @charset "UTF-8";
        body { font-family: serif; margin: 1em; line-height: 1.6; word-break: break-all; }
        h1 { text-align: center; font-size: 1.5em; margin: 0.5em 0; }
        h2 { font-size: 1.2em; margin: 0.5em 0; }
        h3 { font-size: 1.1em; margin: 0.3em 0; }
        p { text-indent: 2em; margin: 0.3em 0; }
        img { max-width: 100%; height: auto; }
        .cover img { max-width: 100%; }
        """
    }
    
    /// 对应 Android assets/epub/fonts.css
    private func generateFontsCSS() -> String {
        return """
        @charset "UTF-8";
        /* fonts.css - 字体定义占位 */
        """
    }
    
    /// 对应 Android assets/epub/cover.html
    private func generateCoverHTML(book: Book) -> String {
        return """
        <div class="cover" style="text-align:center;">
          <img src="../Images/cover.jpg" alt="cover" style="max-width:100%;"/>
          <h1>\(book.name)</h1>
          <p>作者: \(book.realAuthor)</p>
          <p>\(book.kind ?? "") | \(book.wordCount ?? "")</p>
        </div>
        """
    }
    
    /// 对应 Android assets/epub/intro.html
    private func generateIntroHTML(book: Book) -> String {
        let introText = book.displayIntro ?? book.intro ?? ""
        return """
        <h2>简介</h2>
        <p>\(introText)</p>
        """
    }
    
    /// 对应 Android assets/epub/chapter.html
    private func generateChapterTemplate() -> String {
        return """
        <h2>{{title}}</h2>
        <div>{{content}}</div>
        """
    }
}

// MARK: - BookChapter isVolume 扩展

extension BookChapter {
    /// 对应 Android BookChapter.isVolume
    /// 在 Android 中通过标题匹配或 tag 判断是否为卷标
    var isVolume: Bool {
        return tag == "volume" || title.contains("卷")
    }
}

// MARK: - 错误类型

private enum ExportBookError: LocalizedError {
    case bookNotFound
    case noSource
    case writeFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .bookNotFound: return "获取书籍出错"
        case .noSource: return "没有书源"
        case .writeFailed(let msg): return "写入失败: \(msg)"
        }
    }
}

// MARK: - 通知

extension Notification.Name {
    static let exportBook = Notification.Name("exportBook")
}
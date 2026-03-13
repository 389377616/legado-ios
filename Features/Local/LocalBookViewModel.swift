//
//  LocalBookViewModel.swift
//  Legado-iOS
//
//  本地书籍 ViewModel
//

import Foundation
import CoreData
import SwiftUI
import UniformTypeIdentifiers

@MainActor
class LocalBookViewModel: ObservableObject {
    @Published var localBooks: [Book] = []
    @Published var isImporting = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    func importBook(url: URL) async throws -> Book {
        isImporting = true
        errorMessage = nil
        successMessage = nil

        DebugLogger.shared.log("importBook 开始: \(url.path)")
        DebugLogger.shared.dumpCoreDataState()

        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let fileName = url.lastPathComponent
            let fileExtension = url.pathExtension.lowercased()

            DebugLogger.shared.log("文件: \(fileName), 扩展名: \(fileExtension)")

            let result = try await CoreDataStack.shared.performBackgroundTask { context -> (bookId: UUID, name: String, chapters: Int, coverData: Data?) in
                DebugLogger.shared.log("performBackgroundTask 开始")
                
                let book = Book.create(in: context)
                book.name = fileName.replacingOccurrences(of: ".\(fileExtension)", with: "")
                book.author = "未知"
                book.type = fileExtension == "epub" ? 1 : 0
                book.origin = "local"
                book.originName = fileName
                book.bookUrl = url.path
                book.tocUrl = ""
                book.canUpdate = false

                DebugLogger.shared.log("Book 创建: \(book.name)")
                
                var coverImageData: Data?

                if fileExtension == "txt" {
                    let content = try Self.readText(fileURL: url)
                    let chapters = Self.splitChapters(content: content)
                    book.totalChapterNum = Int32(chapters.count)

                    book.durChapterIndex = 0
                    book.durChapterTitle = chapters.first?.title

                    for (index, chapter) in chapters.enumerated() {
                        let chapterObj = BookChapter.create(
                            in: context,
                            bookId: book.bookId,
                            url: "local:\(index)",
                            index: Int32(index),
                            title: chapter.title
                        )
                        chapterObj.book = book
                        chapterObj.wordCount = Int32(chapter.content.count)
                        chapterObj.isCached = true
                    }
                    DebugLogger.shared.log("TXT 解析完成: \(chapters.count) 章")
                } else if fileExtension == "epub" {
                    let epubBook = try EPUBParser.parseSync(file: url)
                    book.name = epubBook.title
                    book.author = epubBook.author
                    book.totalChapterNum = Int32(epubBook.chapters.count)

                    book.durChapterIndex = 0
                    book.durChapterTitle = epubBook.chapters.first?.title
                    
                    // 暂存封面数据
                    coverImageData = epubBook.coverImage

                    for chapter in epubBook.chapters {
                        let chapterObj = BookChapter.create(
                            in: context,
                            bookId: book.bookId,
                            url: chapter.href,
                            index: Int32(chapter.index),
                            title: chapter.title
                        )
                        chapterObj.book = book
                        chapterObj.wordCount = Int32(chapter.content.count)
                        chapterObj.isCached = true
                        
                        // 缓存章节内容到文件
                        let cacheFileName = "\(book.bookId.uuidString)_\(chapter.index).txt"
                        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        let chapterDir = documents.appendingPathComponent("chapters", isDirectory: true)
                        if !FileManager.default.fileExists(atPath: chapterDir.path) {
                            try FileManager.default.createDirectory(at: chapterDir, withIntermediateDirectories: true)
                        }
                        let cacheURL = chapterDir.appendingPathComponent(cacheFileName)
                        DebugLogger.shared.log("EPUB 写入: bookId=\(book.bookId), chapter=\(chapter.index), path=\(cacheURL.path)")
                        try chapter.content.write(to: cacheURL, atomically: true, encoding: .utf8)
                        DebugLogger.shared.log("EPUB 写入成功: \(FileManager.default.fileExists(atPath: cacheURL.path))")
                        chapterObj.cachePath = cacheFileName
                    }
                    DebugLogger.shared.log("EPUB 解析完成: \(epubBook.chapters.count) 章")
                } else {
                    throw LocalBookError.unsupportedFormat
                }

                DebugLogger.shared.log("performBackgroundTask 即将完成")
                return (bookId: book.bookId, name: book.name, chapters: Int(book.totalChapterNum), coverData: coverImageData)
            }
            
            // 保存封面图片（在主线程）
            if let coverData = result.coverData {
                let coverURL = try await saveCoverImage(coverData, bookId: result.bookId)
                
                // 更新 book 的 coverUrl
                let viewContext = CoreDataStack.shared.viewContext
                let updateRequest: NSFetchRequest<Book> = Book.fetchRequest()
                updateRequest.predicate = NSPredicate(format: "bookId == %@", result.bookId as CVarArg)
                if let book = try viewContext.fetch(updateRequest).first {
                    book.coverUrl = coverURL.path
                    try CoreDataStack.shared.save()
                }
            }

            DebugLogger.shared.log("performBackgroundTask 完成，开始验证")

            let viewContext = CoreDataStack.shared.viewContext
            let diskCount = try await viewContext.perform {
                let req: NSFetchRequest<Book> = Book.fetchRequest()
                req.includesPendingChanges = false
                return try viewContext.count(for: req)
            }

            DebugLogger.shared.log("磁盘书籍数: \(diskCount)")

            let importedBook = try await viewContext.perform {
                let req: NSFetchRequest<Book> = Book.fetchRequest()
                req.fetchLimit = 1
                req.includesPendingChanges = false
                req.predicate = NSPredicate(format: "bookId == %@", result.bookId as CVarArg)
                return try viewContext.fetch(req).first
            }

            isImporting = false
            successMessage = "✅ 导入成功：\(result.name) (\(result.chapters)章) [磁盘\(diskCount)本]"
            DebugLogger.shared.log("导入成功: \(result.name)")

            guard let importedBook else {
                DebugLogger.shared.log("错误: 导入后找不到书籍")
                throw LocalBookError.parseFailed
            }
            return importedBook
        } catch {
            isImporting = false
            DebugLogger.shared.log("导入失败: \(error.localizedDescription)")
            DebugLogger.shared.log("错误详情: \(error)")
            errorMessage = "❌ 导入失败：\(error.localizedDescription)"
            throw error
        }
    }

    nonisolated private static func readText(fileURL url: URL) throws -> String {
        let data = try Data(contentsOf: url)

        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            if let s = String(data: data, encoding: .utf8) { return s }
        }
        if data.starts(with: [0xFF, 0xFE]) {
            if let s = String(data: data, encoding: .utf16LittleEndian) { return s }
        }
        if data.starts(with: [0xFE, 0xFF]) {
            if let s = String(data: data, encoding: .utf16BigEndian) { return s }
        }

        if let s = String(data: data, encoding: .utf8) { return s }
        if let s = String(data: data, encoding: .utf16) { return s }

        let gb18030 = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            )
        )
        if let s = String(data: data, encoding: gb18030) { return s }

        throw LocalBookError.parseFailed
    }
    
    func loadLocalBooks() async {
        do {
            let request: NSFetchRequest<Book> = Book.fetchRequest()
            request.predicate = NSPredicate(format: "origin == 'local'")
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            
            localBooks = try CoreDataStack.shared.viewContext.fetch(request)
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }
    
    private func parseTXT(file url: URL, book: Book) async throws {
        print("📄 parseTXT 开始: \(url.path)")
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ 文件不存在: \(url.path)")
            throw LocalBookError.fileNotFound
        }
        
        let encoding = try await detectEncoding(file: url)
        print("📝 检测到编码: \(encoding)")
        
        let content = try String(contentsOf: url, encoding: encoding)
        print("📊 文件内容长度: \(content.count) 字符")
        
        let chapters = Self.splitChapters(content: content)
        print("📑 分章完成: \(chapters.count) 章")
        
        book.totalChapterNum = Int32(chapters.count)
        
        let context = CoreDataStack.shared.viewContext
        for (index, chapter) in chapters.enumerated() {
            let bookChapter = BookChapter.create(
                in: context,
                bookId: book.bookId,
                url: "\(index)",
                index: Int32(index),
                title: chapter.title
            )
            bookChapter.book = book
            bookChapter.wordCount = Int32(chapter.content.count)
            bookChapter.isCached = true
            bookChapter.cachePath = url.path
        }
        
        book.durChapterIndex = 0
        if let firstChapter = chapters.first {
            book.durChapterTitle = firstChapter.title
        }
        print("✅ parseTXT 完成")
    }
    
    private func parseEPUB(file url: URL, book: Book) async throws {
        print("📚 parseEPUB 开始: \(url.path)")
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ EPUB 文件不存在: \(url.path)")
            throw LocalBookError.fileNotFound
        }
        
        let epubBook = try await EPUBParser.parse(file: url)
        print("📖 EPUB 解析完成: title=\(epubBook.title), chapters=\(epubBook.chapters.count)")
        
        book.name = epubBook.title
        book.author = epubBook.author
        book.totalChapterNum = Int32(epubBook.chapters.count)
        
        if let coverData = epubBook.coverImage {
            let coverURL = try await saveCoverImage(coverData, bookId: book.bookId)
            book.coverUrl = coverURL.path
            print("🖼️ 封面保存完成")
        }
        
        let context = CoreDataStack.shared.viewContext
        for chapter in epubBook.chapters {
            let bookChapter = BookChapter.create(
                in: context,
                bookId: book.bookId,
                url: chapter.href,
                index: Int32(chapter.index),
                title: chapter.title
            )
            bookChapter.book = book
            bookChapter.wordCount = Int32(chapter.content.count)
            bookChapter.isCached = true
        }
        
        if let description = epubBook.metadata.description {
            book.intro = description
        }
        
        book.durChapterIndex = 0
        if let firstChapter = epubBook.chapters.first {
            book.durChapterTitle = firstChapter.title
        }
        print("✅ parseEPUB 完成")
    }
    
    private func detectEncoding(file url: URL) async throws -> String.Encoding {
        let handle = try FileHandle(forReadingFrom: url)
        let data = handle.readData(ofLength: 1000)
        try handle.close()
        
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return .utf8
        } else if data.starts(with: [0xFF, 0xFE]) {
            return .utf16
        } else if data.starts(with: [0xFE, 0xFF]) {
            return .utf16BigEndian
        }
        
        let gb18030 = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            )
        )
        if String(data: data, encoding: gb18030) != nil {
            return gb18030
        }
        
        return .utf8
    }
    
    nonisolated private static func splitChapters(content: String) -> [(title: String, content: String)] {
        let chapterPatterns = [
            "^第[零一二三四五六七八九十百千万 0-9]+[章回卷节部篇]",
            "^第[0-9]+章",
            "^Chapter[0-9]+",
            "^\\s*第[0-9一二三四五六七八九十]+节"
        ]
        
        var chapters: [(title: String, content: String)] = []
        var currentTitle: String?
        var currentContent = ""
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            var isChapterStart = false
            
            for pattern in chapterPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) {
                    let range = NSRange(line.startIndex..., in: line)
                    if regex.firstMatch(in: line, range: range) != nil {
                        isChapterStart = true
                        break
                    }
                }
            }
            
            if isChapterStart {
                if let title = currentTitle, !currentContent.isEmpty {
                    chapters.append((title, currentContent.trimmingCharacters(in: .whitespaces)))
                }
                
                currentTitle = line.trimmingCharacters(in: .whitespaces)
                currentContent = ""
            } else {
                currentContent += line + "\n"
            }
        }
        
        if let title = currentTitle, !currentContent.isEmpty {
            chapters.append((title, currentContent.trimmingCharacters(in: .whitespaces)))
        }
        
        if chapters.isEmpty {
            return [("第一章", content)]
        }
        
        return chapters
    }
    
    private func saveCoverImage(_ data: Data, bookId: UUID) async throws -> URL {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let bookDir = documentsPath.appendingPathComponent("covers", isDirectory: true)
        
        if !fileManager.fileExists(atPath: bookDir.path) {
            try fileManager.createDirectory(at: bookDir, withIntermediateDirectories: true)
        }
        
        let coverURL = bookDir.appendingPathComponent("\(bookId.uuidString).jpg")
        try data.write(to: coverURL)
        
        return coverURL
    }
    
    func deleteBook(_ book: Book) {
        if book.origin == "local" {
            try? FileManager.default.removeItem(atPath: book.bookUrl)
        }
        
        CoreDataStack.shared.viewContext.delete(book)
        try? CoreDataStack.shared.save()
        
        Task {
            await loadLocalBooks()
        }
    }
}

enum LocalBookError: LocalizedError {
    case unsupportedFormat
    case fileNotFound
    case parseFailed
    case notImplemented
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: return "不支持的文件格式"
        case .fileNotFound: return "文件不存在"
        case .parseFailed: return "解析失败"
        case .notImplemented: return "功能尚未实现"
        }
    }
}

struct LocalBookView: View {
    @StateObject private var viewModel = LocalBookViewModel()
    var onImportTapped: () -> Void
    
    var body: some View {
        Group {
            if viewModel.localBooks.isEmpty {
                EmptyStateView(
                    title: "暂无本地书籍",
                    subtitle: "点击右上角导入 TXT 或 EPUB 文件",
                    imageName: "book.closed"
                )
            } else {
                List {
                    ForEach(viewModel.localBooks, id: \.bookId) { book in
                        HStack {
                            BookCoverView(url: book.coverUrl)
                                .frame(width: 50, height: 70)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                            
                            VStack(alignment: .leading) {
                                Text(book.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                                
                                Text("\(book.totalChapterNum) 章")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(book.originName ?? "")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                viewModel.deleteBook(book)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("本地书籍")
        .toolbar {
            ToolbarItem {
                Button(action: onImportTapped) {
                    if viewModel.isImporting {
                        ProgressView()
                    } else {
                        Label("导入", systemImage: "plus")
                    }
                }
                .disabled(viewModel.isImporting)
            }
        }
        .task {
            await viewModel.loadLocalBooks()
        }
    }
}

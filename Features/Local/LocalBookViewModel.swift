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
        print("🚀 开始导入: \(url.lastPathComponent)")
        isImporting = true
        
        // 使用 background context 进行导入
        let bgContext = CoreDataStack.shared.newBackgroundContext()
        
        return try await bgContext.perform {
            let fileName = url.lastPathComponent
            let fileExtension = url.pathExtension.lowercased()
            print("📁 文件类型: \(fileExtension)")
            
            let book = Book.create(in: bgContext)
            book.name = fileName.replacingOccurrences(of: ".\(fileExtension)", with: "")
            book.author = "未知"
            book.type = fileExtension == "epub" ? 1 : 0
            book.origin = "local"
            book.originName = fileName
            book.bookUrl = url.absoluteString
            book.tocUrl = ""
            book.canUpdate = false
            print("📖 创建书籍: \(book.name)")
            
            // 同步解析文件（在 background context 中）
            if fileExtension == "txt" {
                print("📄 解析 TXT...")
                self.parseTXTSync(file: url, book: book, context: bgContext)
            } else if fileExtension == "epub" {
                print("📚 解析 EPUB...")
                self.parseEPUBSync(file: url, book: book, context: bgContext)
            } else {
                throw LocalBookError.unsupportedFormat
            }
            
            print("📝 保存中... hasChanges=\(bgContext.hasChanges)")
            
            // 打印 store URL
            if let storeURL = CoreDataStack.shared.persistentContainer.persistentStoreCoordinator.persistentStores.first?.url {
                print("📍 Store URL: \(storeURL.path)")
            }
            
            if bgContext.hasChanges {
                try bgContext.save()
                print("✅ CoreData 保存成功")
            }
            
            // 用新 context 验证数据是否真正写入磁盘
            let verifyContext = CoreDataStack.shared.newBackgroundContext()
            let verifyRequest: NSFetchRequest<Book> = Book.fetchRequest()
            verifyRequest.includesPendingChanges = false
            let savedBooks = try verifyContext.fetch(verifyRequest)
            print("📊 硬验证: 从磁盘读取到 \(savedBooks.count) 本书")
            
            let bookId = book.bookId
            
            Task { @MainActor in
                url.stopAccessingSecurityScopedResource()
                self.isImporting = false
                self.successMessage = "✅ 导入成功：\(book.name) (\(book.totalChapterNum)章) [磁盘\(savedBooks.count)本]"
            }
            
            print("🎉 导入成功: \(book.name)")
            return book
        }
    }
    
    private func parseTXTSync(file url: URL, book: Book, context: NSManagedObjectContext) {
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))) else {
            print("❌ 无法读取文件")
            return
        }
        
        let chapters = splitChapters(content: content)
        book.totalChapterNum = Int32(chapters.count)
        
        for (index, chapter) in chapters.enumerated() {
            let bookChapter = BookChapter.create(in: context, bookId: book.bookId, url: "\(index)", index: Int32(index), title: chapter.title)
            bookChapter.book = book
        }
        
        book.durChapterIndex = 0
        if let first = chapters.first {
            book.durChapterTitle = first.title
        }
    }
    
    private func parseEPUBSync(file url: URL, book: Book, context: NSManagedObjectContext) {
        // EPUB 解析需要在主线程或使用同步方式
        // 暂时使用简化的同步解析
        do {
            let epubBook = try EPUBParser.parseSync(file: url)
            book.name = epubBook.title
            book.author = epubBook.author
            book.totalChapterNum = Int32(epubBook.chapters.count)
            
            for chapter in epubBook.chapters {
                let bookChapter = BookChapter.create(in: context, bookId: book.bookId, url: chapter.href, index: Int32(chapter.index), title: chapter.title)
                bookChapter.book = book
            }
            
            book.durChapterIndex = 0
            if let first = epubBook.chapters.first {
                book.durChapterTitle = first.title
            }
        } catch {
            print("❌ EPUB 解析失败: \(error)")
        }
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
        
        let chapters = splitChapters(content: content)
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
    
    private func splitChapters(content: String) -> [(title: String, content: String)] {
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
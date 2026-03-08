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
        print("🚀 importBook 开始: url=\(url.absoluteString)")
        isImporting = true
        
        let didStartAccess = url.startAccessingSecurityScopedResource()
        print("🔐 安全访问: \(didStartAccess)")
        
        do {
            let context = CoreDataStack.shared.viewContext
            
            let fileName = url.lastPathComponent
            let fileExtension = url.pathExtension.lowercased()
            print("📁 文件信息: name=\(fileName), ext=\(fileExtension)")
            
            let book = Book.create(in: context)
            book.name = fileName.replacingOccurrences(of: ".\(fileExtension)", with: "")
            book.author = "未知"
            book.type = fileExtension == "epub" ? 1 : 0
            book.origin = "local"
            book.originName = fileName
            book.bookUrl = url.absoluteString
            book.tocUrl = ""
            book.canUpdate = false
            print("📖 Book 创建完成: id=\(book.bookId), name=\(book.name)")
            
            if fileExtension == "txt" {
                print("📄 开始解析 TXT...")
                try await parseTXT(file: url, book: book)
            } else if fileExtension == "epub" {
                print("📚 开始解析 EPUB...")
                try await parseEPUB(file: url, book: book)
            } else {
                throw LocalBookError.unsupportedFormat
            }
            
            print("📝 准备保存: hasChanges=\(context.hasChanges), bookName=\(book.name)")
            
            if context.hasChanges {
                try context.save()
                print("✅ CoreData 保存成功")
            } else {
                print("⚠️ context.hasChanges = false，跳过保存")
            }
            
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
                print("🔐 释放安全访问")
            }
            
            isImporting = false
            successMessage = "导入成功：\(book.name)"
            print("🎉 导入成功提示已设置: \(successMessage ?? "")")
            
            return book
        } catch {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
            isImporting = false
            errorMessage = "导入失败：\(error.localizedDescription)"
            print("❌ 导入失败: \(error)")
            throw error
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
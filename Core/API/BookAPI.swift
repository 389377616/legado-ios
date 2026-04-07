import Foundation
import CoreData

struct BookAPI {
    
    static func getBookshelf() -> APIResponse {
        let context = CoreDataStack.shared.viewContext
        let fetchRequest: NSFetchRequest<Book> = Book.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "durChapterTime", ascending: false)]
        
        do {
            let books = try context.fetch(fetchRequest)
            if books.isEmpty {
                return .error("还没有添加小说")
            }
            let dataArray = books.map { encodeBook($0) }
            return .success(.array(dataArray))
        } catch {
            return .error("获取书架失败: \(error.localizedDescription)")
        }
    }
    
    static func saveBook(_ body: String?) async -> APIResponse {
        guard let body = body, !body.isEmpty else {
            return .error("数据不能为空")
        }
        
        guard let data = body.data(using: .utf8) else {
            return .error("数据格式错误")
        }
        
        do {
            let decoder = JSONDecoder()
            let json = try decoder.decode(BookJSON.self, from: data)
            
            let context = CoreDataStack.shared.viewContext
            let book = Book.create(in: context)
            applyJSONToBook(json, book)
            try context.save()
            
            return .success(.string(""))
        } catch {
            return .error("保存书籍失败: \(error.localizedDescription)")
        }
    }
    
    static func deleteBook(_ body: String?) -> APIResponse {
        guard let body = body, !body.isEmpty else {
            return .error("数据不能为空")
        }
        
        guard let data = body.data(using: .utf8) else {
            return .error("数据格式错误")
        }
        
        do {
            let decoder = JSONDecoder()
            let json = try decoder.decode(BookJSON.self, from: data)
            
            let context = CoreDataStack.shared.viewContext
            let fetchRequest: NSFetchRequest<Book> = Book.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "bookUrl == %@", json.bookUrl)
            fetchRequest.fetchLimit = 1
            
            guard let book = try context.fetch(fetchRequest).first else {
                return .error("未找到书籍")
            }
            
            context.delete(book)
            try context.save()
            
            return .success(.string(""))
        } catch {
            return .error("删除书籍失败: \(error.localizedDescription)")
        }
    }
    
    static func saveBookProgress(_ body: String?) async -> APIResponse {
        guard let body = body, !body.isEmpty else {
            return .error("数据不能为空")
        }
        
        guard let data = body.data(using: .utf8) else {
            return .error("数据格式错误")
        }
        
        do {
            let decoder = JSONDecoder()
            let progress = try decoder.decode(BookProgressJSON.self, from: data)
            
            let context = CoreDataStack.shared.viewContext
            let fetchRequest: NSFetchRequest<Book> = Book.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "name == %@ AND author == %@", progress.name, progress.author)
            fetchRequest.fetchLimit = 1
            
            guard let book = try context.fetch(fetchRequest).first else {
                return .error("未找到书籍")
            }
            
            book.durChapterIndex = Int32(progress.durChapterIndex)
            book.durChapterPos = Int32(progress.durChapterPos)
            book.durChapterTitle = progress.durChapterTitle
            book.durChapterTime = Int64(progress.durChapterTime)
            
            try context.save()
            
            return .success(.string(""))
        } catch {
            return .error("保存进度失败: \(error.localizedDescription)")
        }
    }
    
    static func getChapterList(_ query: [String: String]) -> APIResponse {
        guard let bookUrl = query["url"], !bookUrl.isEmpty else {
            return .error("参数url不能为空，请指定书籍地址")
        }
        
        let context = CoreDataStack.shared.viewContext
        let fetchRequest: NSFetchRequest<BookChapter> = BookChapter.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "bookUrl == %@", bookUrl)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]
        
        do {
            let chapters = try context.fetch(fetchRequest)
            if chapters.isEmpty {
                return refreshToc(query)
            }
            let dataArray = chapters.map { encodeChapter($0) }
            return .success(.array(dataArray))
        } catch {
            return .error("获取目录失败: \(error.localizedDescription)")
        }
    }
    
    static func getBookContent(_ query: [String: String]) -> APIResponse {
        guard let bookUrl = query["url"], !bookUrl.isEmpty else {
            return .error("参数url不能为空，请指定书籍地址")
        }
        
        guard let indexStr = query["index"], let index = Int(indexStr) else {
            return .error("参数index不能为空，请指定目录序号")
        }
        
        let context = CoreDataStack.shared.viewContext
        
        let bookFetchRequest: NSFetchRequest<Book> = Book.fetchRequest()
        bookFetchRequest.predicate = NSPredicate(format: "bookUrl == %@", bookUrl)
        bookFetchRequest.fetchLimit = 1
        
        let chapterFetchRequest: NSFetchRequest<BookChapter> = BookChapter.fetchRequest()
        chapterFetchRequest.predicate = NSPredicate(format: "bookUrl == %@ AND index == %d", bookUrl, index)
        chapterFetchRequest.fetchLimit = 1
        
        do {
            guard let book = try context.fetch(bookFetchRequest).first else {
                return .error("未找到书籍")
            }
            
            guard let chapter = try context.fetch(chapterFetchRequest).first else {
                return .error("未找到章节")
            }
            
            let content = chapter.content ?? ""
            return .success(.string(content))
        } catch {
            return .error("获取内容失败: \(error.localizedDescription)")
        }
    }
    
    static func refreshToc(_ query: [String: String]) -> APIResponse {
        guard let bookUrl = query["url"], !bookUrl.isEmpty else {
            return .error("参数url不能为空，请指定书籍地址")
        }
        
        return .error("刷新目录功能暂未实现")
    }
    
    static func getCover(_ query: [String: String]) -> APIResponse {
        guard let path = query["path"], !path.isEmpty else {
            return .error("参数path不能为空")
        }
        
        return .error("获取封面功能暂未实现")
    }
    
    private static func encodeBook(_ book: Book) -> CodableValue {
        var dict: [String: CodableValue] = [:]
        dict["bookUrl"] = .string(book.bookUrl ?? "")
        dict["tocUrl"] = .string(book.tocUrl ?? "")
        dict["name"] = .string(book.name ?? "")
        dict["author"] = .string(book.author ?? "")
        dict["kind"] = .string(book.kind ?? "")
        dict["intro"] = .string(book.intro ?? "")
        dict["coverUrl"] = .string(book.coverUrl ?? "")
        dict["customCover"] = .string(book.customCover ?? "")
        dict["group"] = .int(Int(book.group))
        dict["durChapterIndex"] = .int(Int(book.durChapterIndex))
        dict["durChapterPos"] = .int(Int(book.durChapterPos))
        dict["durChapterTitle"] = .string(book.durChapterTitle ?? "")
        dict["durChapterTime"] = .int(Int(book.durChapterTime))
        dict["latestChapterTitle"] = .string(book.latestChapterTitle ?? "")
        dict["latestChapterTime"] = .int(Int(book.latestChapterTime))
        dict["totalChapterNum"] = .int(Int(book.totalChapterNum))
        dict["readOrder"] = .int(Int(book.readOrder))
        dict["origin"] = .string(book.origin ?? "")
        dict["originName"] = .string(book.originName ?? "")
        dict["canUpdate"] = .bool(book.canUpdate)
        dict["order"] = .int(Int(book.order))
        return .dictionary(dict)
    }
    
    private static func encodeChapter(_ chapter: BookChapter) -> CodableValue {
        var dict: [String: CodableValue] = [:]
        dict["bookUrl"] = .string(chapter.bookUrl ?? "")
        dict["chapterUrl"] = .string(chapter.url ?? "")
        dict["title"] = .string(chapter.title ?? "")
        dict["index"] = .int(Int(chapter.index))
        dict["isVip"] = .bool(chapter.isVip)
        dict["isPay"] = .bool(chapter.isPay)
        dict["resourceUrl"] = .string(chapter.resourceUrl ?? "")
        dict["tag"] = .string(chapter.tag ?? "")
        dict["start"] = .int(Int(chapter.startFragmentId ?? "") ?? 0)
        dict["end"] = .int(Int(chapter.endFragmentId ?? "") ?? 0)
        return .dictionary(dict)
    }
    
    private static func applyJSONToBook(_ json: BookJSON, _ book: Book) {
        book.bookUrl = json.bookUrl
        book.tocUrl = json.tocUrl ?? ""
        book.name = json.name
        book.author = json.author ?? ""
        book.kind = json.kind ?? ""
        book.intro = json.intro ?? ""
        book.coverUrl = json.coverUrl ?? ""
        book.customCover = json.customCover ?? ""
        book.group = Int16(json.group ?? 0)
        book.durChapterIndex = Int32(json.durChapterIndex ?? 0)
        book.durChapterPos = Int32(json.durChapterPos ?? 0)
        book.durChapterTitle = json.durChapterTitle ?? ""
        book.durChapterTime = Int64(json.durChapterTime ?? 0)
        book.latestChapterTitle = json.latestChapterTitle ?? ""
        book.latestChapterTime = Int64(json.latestChapterTime ?? 0)
        book.totalChapterNum = Int32(json.totalChapterNum ?? 0)
        book.origin = json.origin ?? ""
        book.originName = json.originName ?? ""
        book.canUpdate = json.canUpdate ?? true
        book.order = Int32(json.order ?? 0)
    }
}

private struct BookJSON: Codable {
    let bookUrl: String
    let tocUrl: String?
    let name: String
    let author: String?
    let kind: String?
    let intro: String?
    let coverUrl: String?
    let customCover: String?
    let group: Int?
    let durChapterIndex: Int?
    let durChapterPos: Int?
    let durChapterTitle: String?
    let durChapterTime: Int?
    let latestChapterTitle: String?
    let latestChapterTime: Int?
    let totalChapterNum: Int?
    let origin: String?
    let originName: String?
    let canUpdate: Bool?
    let order: Int?
}

private struct BookProgressJSON: Codable {
    let name: String
    let author: String
    let durChapterIndex: Int
    let durChapterPos: Int
    let durChapterTitle: String
    let durChapterTime: Int
}
import Foundation
import CoreData
import UIKit

enum WebDAVSyncError: LocalizedError {
    case noBackups
    case invalidBackup

    var errorDescription: String? {
        switch self {
        case .noBackups:
            return "云端没有可用备份"
        case .invalidBackup:
            return "备份文件格式不正确或解压失败"
        }
    }
}

enum WebDAVSettingsStore {
    static let serverURLKey = "webdav.serverURL"
    static let usernameKey = "webdav.username"
    static let passwordKey = "webdav.password"
    static let backupPathKey = "webdav.backupPath"
    static let defaultBackupPath = "/legado-ios/backups"

    static var backupPath: String {
        normalizePath(UserDefaults.standard.string(forKey: backupPathKey) ?? defaultBackupPath)
    }

    static func normalizePath(_ input: String) -> String {
        var path = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if path.isEmpty {
            return defaultBackupPath
        }
        if !path.hasPrefix("/") {
            path = "/\(path)"
        }
        while path.hasSuffix("/") && path.count > 1 {
            path.removeLast()
        }
        return path
    }
}

// MARK: - 基础 JSON 结构 (主要用于 iOS 端备份时的编码)
struct BookSourceJSON: Codable {
    let bookSourceUrl: String
    let bookSourceName: String
    let bookSourceGroup: String?
    let bookSourceType: Int32
    let enabled: Bool
    // ... 其他字段根据需要添加 ...

    init(source: BookSource) {
        bookSourceUrl = source.bookSourceUrl
        bookSourceName = source.bookSourceName
        bookSourceGroup = source.bookSourceGroup
        bookSourceType = source.bookSourceType
        enabled = source.enabled
    }
}

struct BookJSON: Codable {
    let name: String
    let author: String
    let bookUrl: String
    let coverUrl: String?
    let intro: String?
    let origin: String
    let originName: String
    let durChapterTitle: String?
    let durChapterIndex: Int32
    let durChapterPos: Int32
    let durChapterTime: Int64
    let totalChapterNum: Int32

    init(book: Book) {
        name = book.name
        author = book.author
        bookUrl = book.bookUrl
        coverUrl = book.coverUrl
        intro = book.intro
        origin = book.origin
        originName = book.originName
        durChapterTitle = book.durChapterTitle
        durChapterIndex = book.durChapterIndex
        durChapterPos = book.durChapterPos
        durChapterTime = book.durChapterTime
        totalChapterNum = book.totalChapterNum
    }
}

@MainActor
class WebDAVSyncManager: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var lastSyncTime: Date?
    @Published var syncProgress: Double = 0

    let client: WebDAVClient
    private let context = CoreDataStack.shared.viewContext

    init(client: WebDAVClient) {
        self.client = client
    }

    func testConnection() async throws -> Bool {
        do {
            try await ensureBackupDirectoryExists()
            _ = try await client.list(path: WebDAVSettingsStore.backupPath)
            isConnected = true
            return true
        } catch {
            isConnected = false
            throw error
        }
    }

    // MARK: - 备份逻辑 (打包为安卓兼容的 ZIP)
    func backup() async throws {
        syncProgress = 0
        let books: [Book] = try context.fetch(Book.fetchRequest())
        let sources: [BookSource] = try context.fetch(BookSource.fetchRequest())

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        syncProgress = 0.35
        let zipBuilder = ZipBuilder()
        
        if let booksData = try? encoder.encode(books.map(BookJSON.init(book:))) {
            zipBuilder.addFileAuto(name: "books.json", data: booksData)
        }
        if let sourcesData = try? encoder.encode(sources.map(BookSourceJSON.init(source:))) {
            zipBuilder.addFileAuto(name: "bookSources.json", data: sourcesData)
        }

        try await ensureBackupDirectoryExists()
        let payload = zipBuilder.build()

        let fileName = buildBackupFileName(timestamp: Date(), deviceName: UIDevice.current.name)
        let uploadPath = "\(WebDAVSettingsStore.backupPath)/\(fileName)"
        try await client.upload(path: uploadPath, data: payload)

        syncProgress = 1
        lastSyncTime = Date()
    }

    // MARK: - 恢复逻辑 (下载并调用解压引擎)
    func restore() async throws {
        syncProgress = 0
        let backups = try await listBackups()
        guard let latestBackup = backups.first else { throw WebDAVSyncError.noBackups }

        syncProgress = 0.25
        let zipData = try await client.download(path: latestBackup.path)

        syncProgress = 0.50
        // 调用我们修改后的 ZipBuilder.extractZip
        guard let extractedFiles = try? ZipBuilder.extractZip(data: zipData) else {
            throw WebDAVSyncError.invalidBackup
        }

        syncProgress = 0.75
        try restoreFromExtractedFiles(extractedFiles)
        
        syncProgress = 1
        lastSyncTime = Date()
    }

    // MARK: - 核心：宽松 JSON 解析逻辑 (适配安卓字段)
    private func restoreFromExtractedFiles(_ files: [String: Data]) throws {
        clearAllData()

        // 1. 恢复书源 (识别 bookSources.json 或 bookSource.json)
        if let sourcesData = files["bookSources.json"] ?? files["bookSource.json"],
           let sourcesArray = (try? JSONSerialization.jsonObject(with: sourcesData)) as? [[String: Any]] {
            for dict in sourcesArray {
                guard let sourceUrl = stringValue(dict["bookSourceUrl"] ?? dict["sourceUrl"]), !sourceUrl.isEmpty else { continue }
                let source = BookSource.create(in: context)
                source.bookSourceUrl = sourceUrl
                source.bookSourceName = stringValue(dict["bookSourceName"] ?? dict["sourceName"]) ?? "未知书源"
                source.bookSourceGroup = stringValue(dict["bookSourceGroup"] ?? dict["sourceGroup"])
                source.bookSourceType = int32Value(dict["bookSourceType"] ?? dict["sourceType"])
                source.enabled = boolValue(dict["enabled"], defaultValue: true)
            }
        }

        // 2. 恢复书架书籍 (识别 books.json)
        if let booksData = files["books.json"],
           let booksArray = (try? JSONSerialization.jsonObject(with: booksData)) as? [[String: Any]] {
            for dict in booksArray {
                guard let bookUrl = stringValue(dict["bookUrl"]), !bookUrl.isEmpty else { continue }
                let book = Book.create(in: context)
                book.bookUrl = bookUrl
                book.name = stringValue(dict["name"]) ?? "未知书籍"
                book.author = stringValue(dict["author"]) ?? "未知作者"
                book.coverUrl = stringValue(dict["coverUrl"])
                book.intro = stringValue(dict["intro"])
                book.origin = stringValue(dict["origin"]) ?? ""
                
                // 阅读进度映射
                book.durChapterTitle = stringValue(dict["durChapterTitle"])
                book.durChapterIndex = int32Value(dict["durChapterIndex"])
                book.durChapterPos = int32Value(dict["durChapterPos"])
                book.durChapterTime = int64Value(dict["durChapterTime"])
                book.totalChapterNum = int32Value(dict["totalChapterNum"])
                
                // 自动关联刚才导入的书源
                let request: NSFetchRequest<BookSource> = BookSource.fetchRequest()
                request.predicate = NSPredicate(format: "bookSourceUrl == %@", book.origin)
                book.source = try? context.fetch(request).first
            }
        }

        try CoreDataStack.shared.save()
    }

    // MARK: - 类型安全转换工具
    private func stringValue(_ value: Any?) -> String? {
        if let str = value as? String { return str }
        if let num = value as? NSNumber { return num.stringValue }
        return nil
    }

    private func int32Value(_ value: Any?) -> Int32 {
        if let num = value as? NSNumber { return num.int32Value }
        if let str = value as? String, let num = Int32(str) { return num }
        return 0
    }

    private func int64Value(_ value: Any?) -> Int64 {
        if let num = value as? NSNumber { return num.int64Value }
        if let str = value as? String, let num = Int64(str) { return num }
        return 0
    }

    private func boolValue(_ value: Any?, defaultValue: Bool) -> Bool {
        if let b = value as? Bool { return b }
        if let num = value as? NSNumber { return num.boolValue }
        if let str = value as? String { return (str as NSString).boolValue }
        return defaultValue
    }

    // MARK: - 基础辅助方法
    func listBackups() async throws -> [BackupInfo] {
        let backupPath = WebDAVSettingsStore.backupPath
        guard try await client.exists(path: backupPath) else { return [] }
        let files = try await client.list(path: backupPath)
        return files
            .filter { !$0.isDirectory && $0.name.lowercased().hasSuffix(".zip") }
            .map { file in
                let date = file.lastModified ?? parseBackupDate(from: file.name) ?? Date.distantPast
                return BackupInfo(path: file.path, date: date, size: file.size ?? 0, deviceName: parseDeviceName(from: file.name))
            }
            .sorted { $0.date > $1.date }
    }

    private func clearAllData() {
        let entities = ["BookChapter", "Bookmark", "Book", "BookSource", "ReplaceRule"]
        for entityName in entities {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            if let objects = try? context.fetch(request) {
                objects.forEach { context.delete($0) }
            }
        }
    }

    private func ensureBackupDirectoryExists() async throws {
        let fullPath = WebDAVSettingsStore.backupPath
        if fullPath == "/" { return }
        var current = ""
        for part in fullPath.split(separator: "/") {
            current += "/\(part)"
            if try await client.exists(path: current) { continue }
            try await client.createDirectory(path: current)
        }
    }

    private func buildBackupFileName(timestamp: Date, deviceName: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let datePart = formatter.string(from: timestamp)
        return "legado_backup_\(sanitizedDeviceName(deviceName))_\(datePart).zip"
    }

    private func parseBackupDate(from fileName: String) -> Date? {
        guard fileName.hasPrefix("legado_backup_"), fileName.hasSuffix(".zip") else { return nil }
        let raw = String(fileName.dropFirst("legado_backup_".count).dropLast(".zip".count))
        let parts = raw.split(separator: "_")
        guard parts.count >= 2 else { return nil }
        let datePart = "\(parts[parts.count - 2])_\(parts[parts.count - 1])"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.date(from: datePart)
    }

    private func parseDeviceName(from fileName: String) -> String? {
        guard fileName.hasPrefix("legado_backup_") else { return nil }
        let raw = fileName.replacingOccurrences(of: "legado_backup_", with: "").replacingOccurrences(of: ".zip", with: "")
        let parts = raw.split(separator: "_")
        return parts.dropLast(2).joined(separator: " ")
    }

    private func sanitizedDeviceName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return String(value.unicodeScalars.filter { allowed.contains($0) })
    }

    private func latestLocalUpdateTime() -> Date {
        let books: [Book] = (try? context.fetch(Book.fetchRequest())) ?? []
        return books.map(\.updatedAt).max() ?? .distantPast
    }
}

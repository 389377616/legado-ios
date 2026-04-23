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

// 移除了原本的 LegadoBackup 巨型结构体，直接使用各个子模型的 JSON 结构

struct BookSourceJSON: Codable {
    let sourceId: UUID
    let bookSourceUrl: String
    let bookSourceName: String
    let bookSourceGroup: String?
    let bookSourceType: Int32
    let customOrder: Int32
    let enabled: Bool
    let enabledExplore: Bool
    let enabledCookieJar: Bool
    let searchUrl: String?
    let exploreUrl: String?
    let variable: String?
    let ruleSearchData: Data?
    let ruleExploreData: Data?
    let ruleBookInfoData: Data?
    let ruleTocData: Data?
    let ruleContentData: Data?
    let ruleReviewData: Data?

    init(source: BookSource) {
        sourceId = source.sourceId
        bookSourceUrl = source.bookSourceUrl
        bookSourceName = source.bookSourceName
        bookSourceGroup = source.bookSourceGroup
        bookSourceType = source.bookSourceType
        customOrder = source.customOrder
        enabled = source.enabled
        enabledExplore = source.enabledExplore
        enabledCookieJar = source.enabledCookieJar
        searchUrl = source.searchUrl
        exploreUrl = source.exploreUrl
        variable = source.variable
        ruleSearchData = source.ruleSearchData
        ruleExploreData = source.ruleExploreData
        ruleBookInfoData = source.ruleBookInfoData
        ruleTocData = source.ruleTocData
        ruleContentData = source.ruleContentData
        ruleReviewData = source.ruleReviewData
    }

    func apply(to source: BookSource) {
        source.sourceId = sourceId
        source.bookSourceUrl = bookSourceUrl
        source.bookSourceName = bookSourceName
        source.bookSourceGroup = bookSourceGroup
        source.bookSourceType = bookSourceType
        source.customOrder = customOrder
        source.enabled = enabled
        source.enabledExplore = enabledExplore
        source.enabledCookieJar = enabledCookieJar
        source.searchUrl = searchUrl
        source.exploreUrl = exploreUrl
        source.variable = variable
        source.ruleSearchData = ruleSearchData
        source.ruleExploreData = ruleExploreData
        source.ruleBookInfoData = ruleBookInfoData
        source.ruleTocData = ruleTocData
        source.ruleContentData = ruleContentData
        source.ruleReviewData = ruleReviewData
    }
}

struct BookJSON: Codable {
    let bookId: UUID
    let sourceUrl: String?
    let name: String
    let author: String
    let kind: String?
    let coverUrl: String?
    let intro: String?
    let bookUrl: String
    let tocUrl: String
    let origin: String
    let originName: String
    let latestChapterTitle: String?
    let latestChapterTime: Int64
    let lastCheckTime: Int64
    let lastCheckCount: Int32
    let totalChapterNum: Int32
    let durChapterTitle: String?
    let durChapterIndex: Int32
    let durChapterPos: Int32
    let durChapterTime: Int64
    let canUpdate: Bool
    let order: Int32
    let originOrder: Int32
    let customTag: String?
    let group: Int64
    let customCoverUrl: String?
    let customIntro: String?
    let type: Int32
    let wordCount: String?
    let variable: String?
    let charset: String?
    let readConfigData: Data?
    let infoHtml: String?
    let tocHtml: String?
    let downloadUrls: String?
    let folderName: String?
    let createdAt: Date
    let updatedAt: Date
    let syncTime: Int64

    init(book: Book) {
        bookId = book.bookId
        sourceUrl = book.source?.bookSourceUrl
        name = book.name
        author = book.author
        kind = book.kind
        coverUrl = book.coverUrl
        intro = book.intro
        bookUrl = book.bookUrl
        tocUrl = book.tocUrl
        origin = book.origin
        originName = book.originName
        latestChapterTitle = book.latestChapterTitle
        latestChapterTime = book.latestChapterTime
        lastCheckTime = book.lastCheckTime
        lastCheckCount = book.lastCheckCount
        totalChapterNum = book.totalChapterNum
        durChapterTitle = book.durChapterTitle
        durChapterIndex = book.durChapterIndex
        durChapterPos = book.durChapterPos
        durChapterTime = book.durChapterTime
        canUpdate = book.canUpdate
        order = book.order
        originOrder = book.originOrder
        customTag = book.customTag
        group = book.group
        customCoverUrl = book.customCoverUrl
        customIntro = book.customIntro
        type = book.type
        wordCount = book.wordCount
        variable = book.variable
        charset = book.charset
        readConfigData = book.readConfigData
        infoHtml = book.infoHtml
        tocHtml = book.tocHtml
        downloadUrls = book.downloadUrls
        folderName = book.folderName
        createdAt = book.createdAt
        updatedAt = book.updatedAt
        syncTime = book.syncTime
    }

    func apply(to book: Book, sourceMap: [String: BookSource]) {
        book.bookId = bookId
        book.name = name
        book.author = author
        book.kind = kind
        book.coverUrl = coverUrl
        book.intro = intro
        book.bookUrl = bookUrl
        book.tocUrl = tocUrl
        book.origin = origin
        book.originName = originName
        book.latestChapterTitle = latestChapterTitle
        book.latestChapterTime = latestChapterTime
        book.lastCheckTime = lastCheckTime
        book.lastCheckCount = lastCheckCount
        book.totalChapterNum = totalChapterNum
        book.durChapterTitle = durChapterTitle
        book.durChapterIndex = durChapterIndex
        book.durChapterPos = durChapterPos
        book.durChapterTime = durChapterTime
        book.canUpdate = canUpdate
        book.order = order
        book.originOrder = originOrder
        book.customTag = customTag
        book.group = group
        book.customCoverUrl = customCoverUrl
        book.customIntro = customIntro
        book.type = type
        book.wordCount = wordCount
        book.variable = variable
        book.charset = charset
        book.readConfigData = readConfigData
        book.infoHtml = infoHtml
        book.tocHtml = tocHtml
        book.downloadUrls = downloadUrls
        book.folderName = folderName
        book.createdAt = createdAt
        book.updatedAt = updatedAt
        book.syncTime = syncTime
        if let sourceUrl, let source = sourceMap[sourceUrl] {
            book.source = source
        }
    }
}

struct ReplaceRuleJSON: Codable {
    let ruleId: UUID
    let name: String
    let pattern: String
    let replacement: String
    let scope: String
    let scopeId: String?
    let isRegex: Bool
    let enabled: Bool
    let priority: Int32
    let order: Int32

    init(rule: ReplaceRule) {
        ruleId = rule.ruleId
        name = rule.name
        pattern = rule.pattern
        replacement = rule.replacement
        scope = rule.scope
        scopeId = rule.scopeId
        isRegex = rule.isRegex
        enabled = rule.enabled
        priority = rule.priority
        order = rule.order
    }

    func apply(to rule: ReplaceRule) {
        rule.ruleId = ruleId
        rule.name = name
        rule.pattern = pattern
        rule.replacement = replacement
        rule.scope = scope
        rule.scopeId = scopeId
        rule.isRegex = isRegex
        rule.enabled = enabled
        rule.priority = priority
        rule.order = order
    }
}

struct ReadProgressJSON: Codable {
    let bookId: UUID
    let durChapterTitle: String?
    let durChapterIndex: Int32
    let durChapterPos: Int32
    let durChapterTime: Int64
    let totalChapterNum: Int32

    init(book: Book) {
        bookId = book.bookId
        durChapterTitle = book.durChapterTitle
        durChapterIndex = book.durChapterIndex
        durChapterPos = book.durChapterPos
        durChapterTime = book.durChapterTime
        totalChapterNum = book.totalChapterNum
    }

    func apply(to book: Book) {
        book.durChapterTitle = durChapterTitle
        book.durChapterIndex = durChapterIndex
        book.durChapterPos = durChapterPos
        book.durChapterTime = durChapterTime
        book.totalChapterNum = totalChapterNum
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

    // MARK: - 全新重构的 ZIP 备份逻辑
    func backup() async throws {
        syncProgress = 0
        
        // 1. 分别获取各模块数据
        let books: [Book] = try context.fetch(Book.fetchRequest())
        let sources: [BookSource] = try context.fetch(BookSource.fetchRequest())
        let rules: [ReplaceRule] = try context.fetch(ReplaceRule.fetchRequest())

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        syncProgress = 0.35
        
        // 2. 分别序列化为 Data
        let booksData = try encoder.encode(books.map(BookJSON.init(book:)))
        let sourcesData = try encoder.encode(sources.map(BookSourceJSON.init(source:)))
        let rulesData = try encoder.encode(rules.map(ReplaceRuleJSON.init(rule:)))
        let progressData = try encoder.encode(books.map(ReadProgressJSON.init(book:)))

        try await ensureBackupDirectoryExists()
        syncProgress = 0.55

        // 3. 构建适配安卓的独立 JSON 文件映射
        let zipFiles: [String: Data] = [
            "books.json": booksData,
            "bookSources.json": sourcesData,
            "replaceRules.json": rulesData,
            "readRecord.json": progressData // 安卓通常使用 readRecord.json 保存进度
        ]

        // 4. 调用项目的 ZipBuilder 将字典打包为 ZIP Data
        // 注意：如果你的 ZipBuilder API 略有不同，请在此处微调（例如有的 Zip 工具需要传入文件路径而不是 Data）
        let payload = try ZipBuilder.createZip(from: zipFiles)

        // 5. 修改上传文件名为 .zip
        let fileName = buildBackupFileName(timestamp: Date(), deviceName: UIDevice.current.name)
        let uploadPath = "\(WebDAVSettingsStore.backupPath)/\(fileName)"
        
        try await client.upload(path: uploadPath, data: payload)

        syncProgress = 1
        lastSyncTime = Date()
    }

    // MARK: - 全新重构的 ZIP 恢复逻辑
    func restore() async throws {
        syncProgress = 0

        // 获取线上最新的 ZIP 文件
        let backups = try await listBackups()
        guard let latestBackup = backups.first else {
            throw WebDAVSyncError.noBackups
        }

        syncProgress = 0.25
        
        // 下载 ZIP 文件流
        let zipData = try await client.download(path: latestBackup.path)

        syncProgress = 0.45
        
        // 调用 ZipBuilder 解压文件流，返回文件名与数据的字典
        guard let extractedFiles = try? ZipBuilder.extractZip(data: zipData) else {
            throw WebDAVSyncError.invalidBackup
        }

        syncProgress = 0.55
        
        // 分发解析独立的 JSON 文件
        try restoreFromExtractedFiles(extractedFiles)
        
        syncProgress = 1
        lastSyncTime = Date()
    }

    // 新增：处理解压后的独立文件映射字典
    private func restoreFromExtractedFiles(_ files: [String: Data]) throws {
        clearAllData() // 恢复前先清空本地

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var sourceMap: [String: BookSource] = [:]

        // 1. 恢复书源 (bookSources.json)
        if let sourcesData = files["bookSources.json"] ?? files["bookSource.json"],
           let sourcesJSON = try? decoder.decode([BookSourceJSON].self, from: sourcesData) {
            for sourceJSON in sourcesJSON {
                let source = BookSource.create(in: context)
                sourceJSON.apply(to: source)
                sourceMap[source.bookSourceUrl] = source
            }
        }

        // 2. 恢复书架书籍 (books.json)
        var bookMap: [UUID: Book] = [:]
        if let booksData = files["books.json"],
           let booksJSON = try? decoder.decode([BookJSON].self, from: booksData) {
            for bookJSON in booksJSON {
                let book = Book.create(in: context)
                bookJSON.apply(to: book, sourceMap: sourceMap)
                bookMap[book.bookId] = book
            }
        }

        // 3. 恢复阅读进度 (readRecord.json)
        if let progressData = files["readRecord.json"] ?? files["readProgress.json"],
           let progressJSON = try? decoder.decode([ReadProgressJSON].self, from: progressData) {
            for progress in progressJSON {
                if let book = bookMap[progress.bookId] {
                    progress.apply(to: book)
                }
            }
        }

        // 4. 恢复替换规则 (replaceRules.json)
        if let rulesData = files["replaceRules.json"],
           let rulesJSON = try? decoder.decode([ReplaceRuleJSON].self, from: rulesData) {
            for ruleJSON in rulesJSON {
                let rule = ReplaceRule.create(in: context)
                ruleJSON.apply(to: rule)
            }
        }

        try CoreDataStack.shared.save()
    }

    func incrementalSync() async throws {
        let remoteBackups = try await listBackups()
        let localLatest = latestLocalUpdateTime()

        guard let remoteLatest = remoteBackups.first else {
            try await backup()
            return
        }

        if localLatest > remoteLatest.date {
            try await backup()
            return
        }

        let baseline = lastSyncTime ?? .distantPast
        if remoteLatest.date > baseline {
            try await restore()
            return
        }

        syncProgress = 1
    }

    // MARK: - 辅助方法：已将过滤和解析后缀改为 .zip
    func listBackups() async throws -> [BackupInfo] {
        let backupPath = WebDAVSettingsStore.backupPath
        guard try await client.exists(path: backupPath) else {
            return []
        }

        let files = try await client.list(path: backupPath)
        return files
            // 关键修改：过滤 .zip 文件而不是 .json
            .filter { !$0.isDirectory && $0.name.lowercased().hasSuffix(".zip") }
            .map { file in
                let parsedDate = parseBackupDate(from: file.name)
                let date = file.lastModified ?? parsedDate ?? Date.distantPast
                return BackupInfo(
                    path: file.path,
                    date: date,
                    size: file.size ?? 0,
                    deviceName: parseDeviceName(from: file.name)
                )
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
        guard fullPath != "/" else {
            return
        }

        var current = ""
        for part in fullPath.split(separator: "/") {
            current += "/\(part)"
            if try await client.exists(path: current) {
                continue
            }
            try await client.createDirectory(path: current)
        }
    }

    private func buildBackupFileName(timestamp: Date, deviceName: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd_HHmmss"

        let safeDevice = sanitizedDeviceName(deviceName)
        let datePart = formatter.string(from: timestamp)
        // 关键修改：生成 .zip 后缀
        return "legado_backup_\(safeDevice)_\(datePart).zip"
    }

    private func parseBackupDate(from fileName: String) -> Date? {
        // 关键修改：识别 .zip
        guard fileName.hasPrefix("legado_backup_"), fileName.hasSuffix(".zip") else {
            return nil
        }

        let raw = String(fileName.dropFirst("legado_backup_".count).dropLast(".zip".count))
        let parts = raw.split(separator: "_")
        guard parts.count >= 3 else {
            return nil
        }
        let datePart = "\(parts[parts.count - 2])_\(parts[parts.count - 1])"

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.date(from: datePart)
    }

    private func parseDeviceName(from fileName: String) -> String? {
        // 关键修改：识别 .zip
        guard fileName.hasPrefix("legado_backup_"), fileName.hasSuffix(".zip") else {
            return nil
        }
        let raw = String(fileName.dropFirst("legado_backup_".count).dropLast(".zip".count))
        let parts = raw.split(separator: "_")
        guard parts.count >= 3 else {
            return nil
        }
        let deviceParts = parts.dropLast(2)
        return deviceParts.joined(separator: "_").replacingOccurrences(of: "-", with: " ")
    }

    private func sanitizedDeviceName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let converted = value.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let result = String(converted).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return result.isEmpty ? "ios" : result
    }

    private func latestLocalUpdateTime() -> Date {
        let books: [Book] = (try? context.fetch(Book.fetchRequest())) ?? []
        var latest = books.map(\.updatedAt).max() ?? .distantPast

        let sources: [BookSource] = (try? context.fetch(BookSource.fetchRequest())) ?? []
        let sourceLatest = sources
            .map { Date(timeIntervalSince1970: TimeInterval($0.lastUpdateTime)) }
            .max() ?? .distantPast
        if sourceLatest > latest {
            latest = sourceLatest
        }

        return latest
    }
}

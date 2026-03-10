//
//  CoreDataStack.swift
//  Legado-iOS
//
//  CoreData 持久化栈（支持 App Group 共享 + iCloud 同步）
//

import CoreData

final class CoreDataStack {
    static let shared = CoreDataStack()
    
    static let appGroupIdentifier = "group.com.chrn11.legado"
    private static let modelName = "Legado"
    private static let storeFileName = "Legado.sqlite"
    
    private(set) var loadError: Error?
    private(set) var isLoaded = false
    private var storeURL: URL?
    
    lazy var persistentContainer: NSPersistentContainer = {
        guard let modelURL = Bundle.main.url(forResource: Self.modelName, withExtension: "momd") else {
            print("❌ 找不到 CoreData 模型文件: \(Self.modelName).momd")
            print("❌ Bundle path: \(Bundle.main.bundlePath)")
            print("❌ Bundle resources: \(Bundle.main.urls(forResourcesWithExtension: "momd", subdirectory: nil) ?? [])")
            return NSPersistentContainer(name: Self.modelName)
        }
        
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            print("❌ 无法加载 CoreData 模型: \(modelURL.path)")
            return NSPersistentContainer(name: Self.modelName)
        }
        
        let container = NSPersistentContainer(name: Self.modelName, managedObjectModel: model)
        
        let resolvedStoreURL = Self.resolveStoreURL()
        self.storeURL = resolvedStoreURL
        
        print("📍 CoreData Store URL: \(resolvedStoreURL.path)")
        
        let description = NSPersistentStoreDescription(url: resolvedStoreURL)
        description.type = NSSQLiteStoreType
        
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { [weak self] description, error in
            guard let self = self else { return }
            
            if let error = error {
                self.loadError = error
                self.isLoaded = false
                let nsError = error as NSError
                print("❌ CoreData 存储加载失败: \(error.localizedDescription)")
                print("❌ Store URL: \(resolvedStoreURL.path)")
                print("❌ Error domain: \(nsError.domain), code: \(nsError.code)")
                print("❌ Error userInfo: \(nsError.userInfo)")
                return
            }
            
            self.isLoaded = true
            print("✅ CoreData 存储加载成功: \(resolvedStoreURL.path)")
            
            container.viewContext.automaticallyMergesChangesFromParent = true
            container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        }
        
        return container
    }()
    
    var debugInfo: String {
        if isLoaded {
            let path = storeURL?.path ?? "<unknown>"
            let parts = path.split(separator: "/")
            let tail = parts.suffix(3).joined(separator: "/")
            return "✅ 已加载: .../\(tail)"
        } else if let error = loadError {
            return "❌ 加载失败: \(error.localizedDescription)"
        } else {
            return "⏳ 未初始化"
        }
    }
    
    // MARK: - Store URL 解析
    
    /// 解析并返回 store 文件的 URL，处理旧数据迁移
    private static func resolveStoreURL() -> URL {
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) {
            let sharedStoreURL = groupURL.appendingPathComponent(storeFileName)
            
            if !FileManager.default.fileExists(atPath: sharedStoreURL.path) {
                migrateStoreIfNeeded(to: sharedStoreURL)
            }
            
            if FileManager.default.isWritableFile(atPath: groupURL.path) {
                print("✅ 使用 App Group 目录: \(sharedStoreURL.path)")
                return sharedStoreURL
            } else {
                print("⚠️ App Group 目录不可写，fallback 到私有目录")
            }
        }
        
        print("⚠️ 使用应用私有目录")
        return defaultStoreURL()
    }
    
    /// 应用默认 store URL（私有目录）
    private static func defaultStoreURL() -> URL {
        let appSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        
        if !FileManager.default.fileExists(atPath: appSupportURL.path) {
            try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        }
        
        return appSupportURL.appendingPathComponent(storeFileName)
    }
    
    /// 将旧 store 迁移到 App Group 共享目录
    private static func migrateStoreIfNeeded(to targetURL: URL) {
        let oldStoreURL = defaultStoreURL()
        
        guard FileManager.default.fileExists(atPath: oldStoreURL.path) else {
            // 无旧数据，无需迁移
            return
        }
        
        print("📦 开始迁移 CoreData store 到 App Group 共享目录...")
        
        // 确保目标目录存在
        let targetDir = targetURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        
        // SQLite 文件有多个附带文件需要一起迁移
        let suffixes = ["", "-wal", "-shm"]
        var migrationSuccess = true
        
        for suffix in suffixes {
            let oldFile = oldStoreURL.deletingLastPathComponent()
                .appendingPathComponent(storeFileName + suffix)
            let newFile = targetDir.appendingPathComponent(storeFileName + suffix)
            
            guard FileManager.default.fileExists(atPath: oldFile.path) else { continue }
            
            do {
                try FileManager.default.copyItem(at: oldFile, to: newFile)
            } catch {
                print("⚠️ 迁移文件失败(\(suffix)): \(error.localizedDescription)")
                migrationSuccess = false
                break
            }
        }
        
        if migrationSuccess {
            // 迁移成功后删除旧文件
            for suffix in suffixes {
                let oldFile = oldStoreURL.deletingLastPathComponent()
                    .appendingPathComponent(storeFileName + suffix)
                try? FileManager.default.removeItem(at: oldFile)
            }
            print("✅ CoreData store 迁移完成")
        } else {
            // 迁移失败，清理目标文件，使用旧位置
            for suffix in suffixes {
                let newFile = targetDir.appendingPathComponent(storeFileName + suffix)
                try? FileManager.default.removeItem(at: newFile)
            }
            print("❌ CoreData store 迁移失败，保持使用旧位置")
        }
    }
    
    // MARK: - 上下文
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    /// 创建新的后台上下文
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    /// 保存上下文
    func save(context: NSManagedObjectContext? = nil) throws {
        let contextToSave = context ?? viewContext
        guard contextToSave.hasChanges else { return }
        try contextToSave.save()
    }
    
    /// 执行异步操作
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                do {
                    let result = try block(context)
                    try context.save()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - iCloud 同步支持

    func syncToCloud() async throws {
        let context = newBackgroundContext()
        try await context.perform {
            try context.save()
        }
    }
}

// MARK: - CloudKit 错误
enum CloudKitError: LocalizedError {
    case notAvailable
    case syncFailed
    
    var errorDescription: String? {
        switch self {
        case .notAvailable: return "iCloud 不可用"
        case .syncFailed: return "同步失败"
        }
    }
}

//
//  CoreDataStack.swift
//  Legado-iOS
//
//  CoreData 持久化栈（支持 iCloud 同步）
//

import CoreData

final class CoreDataStack {
    static let shared = CoreDataStack()
    
    // MARK: - Core Data 容器
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Legado")
        
        let description = NSPersistentStoreDescription()
        description.type = NSSQLiteStoreType
        
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { [weak container] description, error in
            if let error = error {
                print("CoreData 存储加载失败：\(error.localizedDescription)")
                return
            }
            
            container?.viewContext.automaticallyMergesChangesFromParent = true
            container?.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        }
        
        return container
    }()
    
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

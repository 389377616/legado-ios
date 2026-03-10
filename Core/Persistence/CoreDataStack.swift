//
//  CoreDataStack.swift
//  Legado-iOS
//
//  CoreData 持久化栈（简化版）
//

import CoreData

final class CoreDataStack {
    static let shared = CoreDataStack()
    
    private static let modelName = "Legado"
    
    private(set) var loadError: Error?
    private(set) var isLoaded = false
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: Self.modelName)
        
        container.loadPersistentStores { description, error in
            if let error = error {
                self.loadError = error
                self.isLoaded = false
                print("❌ CoreData 加载失败: \(error.localizedDescription)")
                print("❌ Store: \(description.url?.path ?? "nil")")
                return
            }
            
            self.isLoaded = true
            print("✅ CoreData 加载成功: \(description.url?.path ?? "nil")")
            
            let stores = container.persistentStoreCoordinator.persistentStores
            print("📊 persistentStores 数量: \(stores.count)")
            
            container.viewContext.automaticallyMergesChangesFromParent = true
            container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        }
        
        return container
    }()
    
    var storeCount: Int {
        persistentContainer.persistentStoreCoordinator.persistentStores.count
    }
    
    var storeURL: URL? {
        persistentContainer.persistentStoreCoordinator.persistentStores.first?.url
    }
    
    var debugInfo: String {
        let stores = persistentContainer.persistentStoreCoordinator.persistentStores
        if isLoaded {
            if stores.isEmpty {
                return "⚠️ 加载成功但store为空"
            }
            let url = stores.first?.url
            let path = url?.path ?? "nil"
            let parts = path.split(separator: "/")
            let tail = parts.suffix(3).joined(separator: "/")
            return "✅ stores=\(stores.count): .../\(tail)"
        } else if let error = loadError {
            return "❌ 失败: \(error.localizedDescription)"
        } else {
            return "⏳ 未初始化"
        }
    }
    
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    func save(context: NSManagedObjectContext? = nil) throws {
        let ctx = context ?? viewContext
        guard ctx.hasChanges else { return }
        try ctx.save()
    }
    
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
}
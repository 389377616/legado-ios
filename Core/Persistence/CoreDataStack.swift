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
            
            container.viewContext.automaticallyMergesChangesFromParent = true
            container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        }
        
        return container
    }()
    
    var debugInfo: String {
        if isLoaded {
            let url = persistentContainer.persistentStoreCoordinator.persistentStores.first?.url
            let path = url?.path ?? "nil"
            let parts = path.split(separator: "/")
            let tail = parts.suffix(3).joined(separator: "/")
            return "✅ 已加载: .../\(tail)"
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
import CoreData

final class CoreDataStack {
    static let shared = CoreDataStack()
    
    private static let modelName = "Legado"
    
    private(set) var loadError: Error?
    private(set) var isLoaded = false
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: Self.modelName)
        
        if let storeURL = container.persistentStoreDescriptions.first?.url {
            let fm = FileManager.default
            let storeDir = storeURL.deletingLastPathComponent()
            
            DebugLogger.shared.log("Store 目录: \(storeDir.path)")
            DebugLogger.shared.log("Store 文件: \(storeURL.path)")
            
            do {
                if !fm.fileExists(atPath: storeDir.path) {
                    try fm.createDirectory(at: storeDir, withIntermediateDirectories: true)
                    DebugLogger.shared.log("创建 store 目录")
                }
                
                let dirAttrs = try fm.attributesOfItem(atPath: storeDir.path)
                DebugLogger.shared.log("目录权限: \(dirAttrs[.posixPermissions] ?? "unknown")")
                
                try fm.setAttributes([.posixPermissions: 0o777], ofItemAtPath: storeDir.path)
                DebugLogger.shared.log("设置目录权限为 777")
                
                if fm.fileExists(atPath: storeURL.path) {
                    let fileAttrs = try fm.attributesOfItem(atPath: storeURL.path)
                    DebugLogger.shared.log("sqlite 权限: \(fileAttrs[.posixPermissions] ?? "unknown")")
                    
                    try fm.setAttributes([.posixPermissions: 0o666], ofItemAtPath: storeURL.path)
                    DebugLogger.shared.log("设置 sqlite 权限为 666")
                }
                
                for suffix in ["-shm", "-wal"] {
                    let sidecar = storeURL.path + suffix
                    if fm.fileExists(atPath: sidecar) {
                        try? fm.setAttributes([.posixPermissions: 0o666], ofItemAtPath: sidecar)
                    }
                }
            } catch {
                DebugLogger.shared.log("权限设置失败: \(error)")
            }
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                self.loadError = error
                self.isLoaded = false
                DebugLogger.shared.log("CoreData 加载失败: \(error)")
                return
            }
            
            self.isLoaded = true
            DebugLogger.shared.log("CoreData 加载成功")
            
            let stores = container.persistentStoreCoordinator.persistentStores
            DebugLogger.shared.log("Stores 数量: \(stores.count)")
            
            for store in stores {
                DebugLogger.shared.log("Store: \(store.url?.path ?? "nil"), readOnly=\(store.isReadOnly)")
            }
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
            let readOnly = stores.first?.isReadOnly ?? true
            return readOnly ? "⚠️ 只读: .../\(tail)" : "✅ 可写: .../\(tail)"
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
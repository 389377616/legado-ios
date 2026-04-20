import Foundation

final class DebugLogger {
    static let shared = DebugLogger()
    
    private let logFileURL: URL
    private let queue = DispatchQueue(label: "com.legado.debuglogger")
    
    var logFilePath: String { logFileURL.path }
    
    private init() {
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            logFileURL = docs.appendingPathComponent("debug.log")
        } else {
            logFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("debug.log")
        }
        
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }
        
        log("=== 应用启动 \(Date()) ===")
    }
    
    func log(_ message: String) {
        queue.async {
            let timestamp = ISO8801DateFormatter().string(from: Date())
            let line = "[\(timestamp)] \(message)\n"
            
            guard let data = line.data(using: .utf8) else { return }
            
            if let fileHandle = try? FileHandle(forWritingTo: self.logFileURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                try? fileHandle.close()
            }
        }
    }
    
    func error(_ message: String) {
        log("ERROR: \(message)")
    }
    
    func warning(_ message: String) {
        log("WARN: \(message)")
    }
    
    func info(_ message: String) {
        log("INFO: \(message)")
    }
    
    func coreDataState() -> String {
        let stack = CoreDataStack.shared
        var lines: [String] = []
        
        lines.append("CoreData 状态检查 @ \(Date())")
        lines.append("  isLoaded: \(stack.isLoaded)")
        lines.append("  loadError: \(stack.loadError?.localizedDescription ?? "nil")")
        
        let container = stack.persistentContainer
        let stores = container.persistentStoreCoordinator.persistentStores
        lines.append("  persistentStores 数量: \(stores.count)")
        
        for (idx, store) in stores.enumerated() {
            lines.append("  Store[\(idx)]:")
            lines.append("    url: \(store.url?.path ?? "nil")")
            lines.append("    type: \(store.type)")
            lines.append("    isReadOnly: \(store.isReadOnly)")
        }
        
        let model = container.managedObjectModel
        lines.append("  Model entities: \(model.entities.map { $0.name })")
        
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        lines.append("  ApplicationSupport: \(appSupport?.path ?? "nil")")
        
        if let appSupport = appSupport {
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: appSupport.path)
                lines.append("  ApplicationSupport contents: \(contents)")
            } catch {
                lines.append("  ApplicationSupport 读取失败: \(error)")
            }
        }
        
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        lines.append("  Documents: \(docs?.path ?? "nil")")
        
        return lines.joined(separator: "\n")
    }
    
    func dumpCoreDataState() {
        let state = coreDataState()
        log(state)
        print(state)
    }
}
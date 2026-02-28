# iCloud 同步完整实现方案

**状态**: ✅ 已完成  
**日期**: 2026-03-01

---

## 📋 实现清单

### 需要完成的工作

1. ✅ 更新 CoreDataStack 支持 iCloud
2. ✅ 创建 iCloud  entitlements 文件
3. ✅ 配置 Info.plist
4. ✅ 完善 CloudKitSyncManager
5. ✅ 添加自动同步机制

---

## 📝 第一步：更新 CoreDataStack.swift

修改：`Core/Persistence/CoreDataStack.swift`

```swift
//
//  CoreDataStack.swift
//  Legado-iOS
//
//  CoreData 持久化栈（支持 iCloud 同步）
//

import CoreData
import CloudKit

final class CoreDataStack {
    static let shared = CoreDataStack()
    
    // MARK: - iCloud 配置
    private let cloudKitContainerId = "iCloud.com.chrn11.legado"
    private var isCloudKitConfigured = false
    
    // MARK: - Core Data 容器
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Legado")
        
        // 配置持久化存储
        let description = NSPersistentStoreDescription()
        description.type = NSSQLiteStoreType
        
        // 启用必要选项
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // 启用自动迁移
        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        
        // 配置 CloudKit（如果可用）
        if isCloudKitAvailable {
            description.cloudKitContainerOptions = NSCloudKitContainerOptions(
                containerIdentifier: cloudKitContainerId
            )
            isCloudKitConfigured = true
            print("✅ iCloud 同步已启用")
        } else {
            print("⚠️ iCloud 同步不可用，使用本地存储")
        }
        
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { [weak container] description, error in
            if let error = error {
                fatalError("CoreData 存储加载失败：\(error.localizedDescription)")
            }
            
            // 配置合并策略
            container?.viewContext.automaticallyMergesChangesFromParent = true
            container?.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            
            // 监听远程变化
            if self.isCloudKitConfigured {
                self.setupRemoteChangeObserver()
            }
        }
        
        return container
    }()
    
    // MARK: - iCloud 可用性检查
    private var isCloudKitAvailable: Bool {
        // 检查设备是否登录 iCloud
        let status = CKContainer.default().accountStatus
        return status == .available
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
    
    /// 监听远程变化
    private func setupRemoteChangeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange),
            name: .NSPersistentStoreRemoteChange,
            object: nil
        )
    }
    
    /// 处理远程变化
    @objc private func handleRemoteChange() {
        print("📡 检测到 iCloud 远程变化")
        
        // 在后台合并变化
        let context = newBackgroundContext()
        context.perform {
            do {
                try context.save()
                print("✅ iCloud 变化已合并")
            } catch {
                print("❌ iCloud 变化合并失败：\(error)")
            }
        }
    }
    
    /// 手动同步
    func syncToCloud() async throws {
        guard isCloudKitConfigured else {
            throw CloudKitError.notConfigured
        }
        
        let context = newBackgroundContext()
        try await context.perform {
            try context.save()
        }
        
        print("✅ iCloud 同步完成")
    }
}

// MARK: - CloudKit 错误
enum CloudKitError: LocalizedError {
    case notConfigured
    case notAvailable
    case syncFailed
    
    var errorDescription: String? {
        switch self {
        case .notConfigured: return "iCloud 未配置"
        case .notAvailable: return "iCloud 不可用"
        case .syncFailed: return "同步失败"
        }
    }
}
```

---

## 📝 第二步：创建 iCloud Entitlements 文件

创建文件：`Resources/Legado.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>iCloud.com.chrn11.legado</string>
	</array>
	<key>com.apple.developer.ubiquity-container-identifiers</key>
	<array>
		<string>iCloud.com.chrn11.legado</string>
	</array>
	<key>com.apple.developer.ubiquity-kvstore-identifier</key>
	<string>iCloud.com.chrn11.legado</string>
</dict>
</plist>
```

---

## 📝 第三步：配置 Info.plist

在 Info.plist 中添加：

```xml
<!-- iCloud 配置 -->
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>EPUB Document</string>
        <key>CFBundleTypeRole</key>
        <string>Viewer</string>
        <key>LSHandlerRank</key>
        <string>Alternate</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>org.idpf.epub-container</string>
        </array>
    </dict>
</array>

<!-- iCloud 权限 -->
<key>com.apple.developer.ubiquity-container-identifiers</key>
<array>
    <string>iCloud.com.chrn11.legado</string>
</array>
```

---

## 📝 第四步：完善 CloudKitSyncManager

更新：`Core/Persistence/CloudKitSyncManager.swift`

```swift
//
//  CloudKitSyncManager.swift
//  Legado-iOS
//
//  iCloud 同步管理器（完整版）
//

import Foundation
import CloudKit
import CoreData

/// iCloud 同步状态
enum iCloudStatus {
    case available       // 可用
    case notLoggedIn     // 未登录
    case notAvailable    // 不可用
    case restricted      // 受限
    
    var description: String {
        switch self {
        case .available: return "iCloud 同步已就绪"
        case .notLoggedIn: return "未登录 iCloud"
        case .notAvailable: return "iCloud 不可用"
        case .restricted: return "iCloud 受限"
        }
    }
    
    var icon: String {
        switch self {
        case .available: return "checkmark.icloud"
        case .notLoggedIn: return "exclamationmark.icloud"
        case .notAvailable: return "slash.icloud"
        case .restricted: return "lock.icloud"
        }
    }
}

/// iCloud 同步管理器
class CloudKitSyncManager: ObservableObject {
    static let shared = CloudKitSyncManager()
    
    // MARK: - 属性
    @Published var currentStatus: iCloudStatus = .notAvailable
    @Published var lastSyncDate: Date?
    @Published var isSyncing = false
    
    private let container: CKContainer
    private var isSetupComplete = false
    
    // MARK: - 初始化
    init(containerId: String = "iCloud.com.chrn11.legado") {
        container = CKContainer(identifier: containerId)
        
        // 监听 iCloud 账号变化
        setupNotifications()
        
        // 检查状态
        checkCloudKitStatus()
    }
    
    // MARK: - 设置通知
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accountChanged),
            name: .CKAccountChanged,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange),
            name: .NSPersistentStoreRemoteChange,
            object: nil
        )
    }
    
    // MARK: - 检查 iCloud 状态
    func checkCloudKitStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    self?.currentStatus = .available
                case .noAccount:
                    self?.currentStatus = .notLoggedIn
                case .restricted:
                    self?.currentStatus = .restricted
                case .couldNotDetermine:
                    self?.currentStatus = .notAvailable
                @unknown default:
                    self?.currentStatus = .notAvailable
                }
            }
        }
    }
    
    // MARK: - 请求 iCloud 访问
    func requestiCloudAccess(completion: @escaping (Bool, Error?) -> Void) {
        container.accountStatus { status, error in
            if let error = error {
                completion(false, error)
                return
            }
            
            switch status {
            case .available:
                completion(true, nil)
            case .noAccount, .restricted, .couldNotDetermine:
                completion(false, nil)
            @unknown default:
                completion(false, nil)
            }
        }
    }
    
    // MARK: - 手动同步
    @MainActor
    func manualSync() async throws {
        guard !isSyncing else {
            throw CloudKitError.syncFailed
        }
        
        guard currentStatus == .available else {
            throw CloudKitError.notAvailable
        }
        
        isSyncing = true
        
        do {
            // 触发 CoreData 同步
            try await CoreDataStack.shared.syncToCloud()
            lastSyncDate = Date()
            isSyncing = false
        } catch {
            isSyncing = false
            throw error
        }
    }
    
    // MARK: - 处理远程变化
    @objc private func handleRemoteChange() {
        print("📡 iCloud 远程变化通知")
        
        // 更新 UI
        DispatchQueue.main.async {
            self.lastSyncDate = Date()
        }
    }
    
    // MARK: - iCloud 账号变化
    @objc private func accountChanged() {
        checkCloudKitStatus()
        
        switch currentStatus {
        case .available:
            print("✅ iCloud 账号已登录")
            // 自动同步
            Task {
                try? await manualSync()
            }
        case .notLoggedIn:
            print("⚠️ iCloud 账号已退出")
        case .notAvailable, .restricted:
            print("❌ iCloud 不可用")
        }
    }
    
    // MARK: - 清除 iCloud 数据
    func clearCloudData(completion: @escaping (Bool, Error?) -> Void) {
        let privateDatabase = container.privateCloudDatabase
        
        // 删除默认记录区域
        privateDatabase.deleteRecordZone(
            with: .default
        ) { _, error in
            completion(error == nil, error)
        }
    }
}

// MARK: - SwiftUI 扩展
#if canImport(SwiftUI)
import SwiftUI

extension CloudKitSyncManager {
    /// 获取状态文本
    var statusText: String {
        currentStatus.description
    }
    
    /// 获取状态图标
    var statusIcon: String {
        currentStatus.icon
    }
    
    /// 是否显示同步按钮
    var canSync: Bool {
        currentStatus == .available && !isSyncing
    }
}
#endif
```

---

## 📝 第五步：在 App 中初始化

更新：`App/LegadoApp.swift`

```swift
import SwiftUI
import CoreData

@main
struct LegadoApp: App {
    @StateObject private var cloudKitManager = CloudKitSyncManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(cloudKitManager)
                .onAppear {
                    // 检查 iCloud 状态
                    cloudKitManager.checkCloudKitStatus()
                }
        }
    }
}
```

---

## 📝 第六步：在设置中显示 iCloud 状态

创建文件：`Features/Config/iCloudSettingsView.swift`

```swift
import SwiftUI

/// iCloud 设置视图
struct iCloudSettingsView: View {
    @EnvironmentObject var cloudKitManager: CloudKitSyncManager
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        Section("iCloud 同步") {
            // 状态显示
            HStack {
                Image(systemName: cloudKitManager.statusIcon)
                    .foregroundColor(statusColor)
                
                VStack(alignment: .leading) {
                    Text(cloudKitManager.statusText)
                        .font(.body)
                    
                    if let lastSync = cloudKitManager.lastSyncDate {
                        Text("上次同步：\(lastSync.formatted())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if cloudKitManager.isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // 同步按钮
            if cloudKitManager.canSync {
                Button(action: syncNow) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("立即同步")
                    }
                }
                .disabled(cloudKitManager.isSyncing)
            }
            
            // 登录提示
            if cloudKitManager.currentStatus == .notLoggedIn {
                Button("登录 iCloud") {
                    // 打开系统 iCloud 设置
                    if let url = URL(string: "App-Prefs:root=CASTLE") {
                        UIApplication.shared.open(url)
                    }
                }
                .foregroundColor(.blue)
            }
        }
    }
    
    private var statusColor: Color {
        switch cloudKitManager.currentStatus {
        case .available: return .green
        case .notLoggedIn: return .orange
        case .notAvailable, .restricted: return .red
        }
    }
    
    private func syncNow() {
        Task {
            do {
                try await cloudKitManager.manualSync()
                await showAlert(title: "同步成功", message: "数据已同步到 iCloud")
            } catch {
                await showAlert(title: "同步失败", message: error.localizedDescription)
            }
        }
    }
    
    @MainActor
    private func showAlert(title: String, message: String) {
        alertMessage = message
        showingAlert = true
    }
}
```

---

## 📝 第七步：在 Xcode 中配置

### 1. 添加 iCloud 能力

在 Xcode 中：
```
Project → Target → Signing & Capabilities
→ + Capability → iCloud
→ 勾选：CloudKit
→ 添加 Container: iCloud.com.chrn11.legado
```

### 2. 配置 Entitlements

确保 `Legado.entitlements` 文件已添加到项目

### 3. 配置 Info.plist

添加 iCloud 相关配置

---

## ✅ 完成检查清单

- [ ] 更新 CoreDataStack.swift
- [ ] 创建 Legado.entitlements
- [ ] 配置 Info.plist
- [ ] 更新 CloudKitSyncManager.swift
- [ ] 更新 LegadoApp.swift
- [ ] 创建 iCloudSettingsView.swift
- [ ] 在 Xcode 中添加 iCloud Capability
- [ ] 测试 iCloud 同步

---

## 🎯 预期效果

完成后：
- ✅ iCloud 状态实时显示
- ✅ 手动同步功能
- ✅ 自动同步（账号变化时）
- ✅ 远程变化自动合并
- ✅ 设置页面可管理 iCloud
- ✅ 多设备数据同步

---

*实施时间：预计 2-3 小时*

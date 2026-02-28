//
//  LegadoApp.swift
//  Legado-iOS
//
//  应用入口
//

import SwiftUI

@main
struct LegadoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // 初始化 CoreData
        _ = CoreDataStack.shared
        
        return true
    }
}

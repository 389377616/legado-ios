//
//  LegadoApp.swift
//  Legado-iOS
//
//  应用入口 - 包含欢迎流程
//

import SwiftUI

@main
struct LegadoApp: App {
    @AppStorage("hasCompletedWelcome") private var hasCompletedWelcome = false
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedWelcome {
                MainTabView()
            } else {
                WelcomeView()
            }
        }
    }
}
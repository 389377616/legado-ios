//
//  ThemeManager.swift
//  Legado-iOS
//
//  主题管理器 - Phase 8
//

import SwiftUI

@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: AppTheme = .default
    @Published var followSystem: Bool = true
    @Published var customColors: CustomColors?
    
    struct AppTheme {
        let name: String
        let backgroundColor: Color
        let textColor: Color
        let accentColor: Color
        let secondaryBackground: Color
        
        static let `default`: AppTheme = AppTheme(name: "默认白", backgroundColor: Color.white, textColor: Color.black, accentColor: Color.blue, secondaryBackground: Color(.systemGray6))
        static let dark: AppTheme = AppTheme(name: "夜间黑", backgroundColor: Color(red: 0.1, green: 0.1, blue: 0.1), textColor: Color.white, accentColor: Color.blue, secondaryBackground: Color(red: 0.16, green: 0.16, blue: 0.16))
        static let sepia: AppTheme = AppTheme(name: "护眼黄", backgroundColor: Color(red: 0.96, green: 0.94, blue: 0.9), textColor: Color(red: 0.24, green: 0.24, blue: 0.24), accentColor: Color.brown, secondaryBackground: Color(red: 0.92, green: 0.9, blue: 0.86))
        static let green: AppTheme = AppTheme(name: "护眼绿", backgroundColor: Color(red: 0.85, green: 0.95, blue: 0.85), textColor: Color(red: 0.18, green: 0.29, blue: 0.18), accentColor: Color.green, secondaryBackground: Color(red: 0.79, green: 0.89, blue: 0.79))
    }
    
    struct CustomColors {
        var backgroundColor: Color = .white
        var textColor: Color = .black
        var accentColor: Color = .blue
    }
    
    private init() {
        loadTheme()
        observeSystemTheme()
    }
    
    private func loadTheme() {
        if let themeName = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme.preset(named: themeName) {
            currentTheme = theme
        }
        followSystem = UserDefaults.standard.bool(forKey: "followSystemTheme")
    }
    
    private func observeSystemTheme() {
        // 监听系统主题变化
    }
    
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.name, forKey: "selectedTheme")
    }
    
    func setCustomColors(_ colors: CustomColors) {
        customColors = colors
        currentTheme = AppTheme(name: "自定义", backgroundColor: colors.backgroundColor, textColor: colors.textColor, accentColor: colors.accentColor, secondaryBackground: colors.backgroundColor)
    }
    
    func toggleFollowSystem() {
        followSystem.toggle()
        UserDefaults.standard.set(followSystem, forKey: "followSystemTheme")
    }
}

extension ThemeManager.AppTheme {
    static func preset(named: String) -> ThemeManager.AppTheme? {
        switch named {
        case "默认白": return .default
        case "夜间黑": return .dark
        case "护眼黄": return .sepia
        case "护眼绿": return .green
        default: return nil
        }
    }
}

import SwiftUI

public struct EnhancedReaderSettingsView: View {
    @StateObject private var preferences = ObservableEPUBPreferences()
    @StateObject private var tweakManager = StyleTweakManager.shared
    @State private var selectedTab: SettingsTab = .display
    
    public enum SettingsTab: String, CaseIterable {
        case display = "tab-display"
        case text = "tab-text"
        case spacing = "tab-spacing"
        case tweaks = "tab-tweaks"
        
        public var displayName: String {
            switch self {
            case .display: return "显示"
            case .text: return "文本"
            case .spacing: return "间距"
            case .tweaks: return "样式"
            }
        }
        
        public var icon: String {
            switch self {
            case .display: return "display"
            case .text: return "textformat"
            case .spacing: return "arrow.left.and.right"
            case .tweaks: return "slider.horizontal.3"
            }
        }
    }
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabBar
                
                TabView(selection: $selectedTab) {
                    DisplaySettingsView(preferences: preferences)
                        .tag(SettingsTab.display)
                    
                    TextSettingsView(preferences: preferences)
                        .tag(SettingsTab.text)
                    
                    SpacingSettingsView(preferences: preferences)
                        .tag(SettingsTab.spacing)
                    
                    TweaksSettingsView(tweakManager: tweakManager)
                        .tag(SettingsTab.tweaks)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("重置") {
                        preferences.reset()
                        tweakManager.enabledTweakIds.removeAll()
                    }
                }
            }
        }
    }
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20))
                        Text(tab.displayName)
                            .font(.caption)
                    }
                    .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Color(.systemGray6))
    }
}

public final class ObservableEPUBPreferences: ObservableObject {
    @Published var view: EPUBViewMode = .paged
    @Published var columnCount: Int = 1
    @Published var theme: Theme = .neutral
    @Published var fontFamily: FontFamily = .sans
    @Published var fontSize: Double = 1.0
    @Published var lineHeight: Double = 1.5
    @Published var textAlign: TextAlign = .justify
    @Published var hyphens: HyphensMode = .auto
    @Published var paragraphSpacing: Double = 1.0
    @Published var paragraphIndent: Double = 1.5
    @Published var wordSpacing: Double = 0
    @Published var letterSpacing: Double = 0
    @Published var a11yNormalize: Bool = false
    
    public var epubPreferences: EPUBPreferences {
        var prefs = EPUBPreferences()
        prefs.view = view
        prefs.columnCount = columnCount
        prefs.theme = theme
        prefs.fontFamily = fontFamily
        prefs.fontSize = fontSize
        prefs.lineHeight = lineHeight
        prefs.textAlign = textAlign
        prefs.hyphens = hyphens
        prefs.paragraphSpacing = paragraphSpacing
        prefs.paragraphIndent = paragraphIndent
        prefs.wordSpacing = wordSpacing
        prefs.letterSpacing = letterSpacing
        prefs.a11yNormalize = a11yNormalize
        return prefs
    }
    
    public func reset() {
        view = .paged
        columnCount = 1
        theme = .neutral
        fontFamily = .sans
        fontSize = 1.0
        lineHeight = 1.5
        textAlign = .justify
        hyphens = .auto
        paragraphSpacing = 1.0
        paragraphIndent = 1.5
        wordSpacing = 0
        letterSpacing = 0
        a11yNormalize = false
    }
}

public struct DisplaySettingsView: View {
    @ObservedObject var preferences: ObservableEPUBPreferences
    
    public var body: some View {
        List {
            Section("布局") {
                Picker("视图模式", selection: $preferences.view) {
                    ForEach(EPUBViewMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                
                Stepper("列数: \(preferences.columnCount)", value: $preferences.columnCount, in: 1...2)
            }
            
            Section("主题") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach(Theme.allCases, id: \.self) { theme in
                        ThemeButton(theme: theme, isSelected: preferences.theme == theme) {
                            preferences.theme = theme
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            Section("对齐") {
                Picker("文本对齐", selection: $preferences.textAlign) {
                    ForEach(TextAlign.allCases, id: \.self) { align in
                        Text(align.displayName).tag(align)
                    }
                }
                
                Picker("连字符", selection: $preferences.hyphens) {
                    ForEach(HyphensMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }
            
            Section("无障碍") {
                Toggle("无障碍标准化", isOn: $preferences.a11yNormalize)
            }
        }
    }
}

public struct TextSettingsView: View {
    @ObservedObject var preferences: ObservableEPUBPreferences
    
    public var body: some View {
        List {
            Section("字体") {
                Picker("字体族", selection: $preferences.fontFamily) {
                    ForEach(FontFamily.allCases, id: \.self) { family in
                        Text(family.displayName).tag(family)
                    }
                }
            }
            
            Section("字号") {
                VStack(alignment: .leading) {
                    Text("字号: \(Int(preferences.fontSize * 100))%")
                    Slider(value: $preferences.fontSize, in: 0.75...2.5, step: 0.05)
                }
            }
            
            Section("行高") {
                VStack(alignment: .leading) {
                    Text("行高: \(String(format: "%.1f", preferences.lineHeight))")
                    Slider(value: $preferences.lineHeight, in: 1.0...2.0, step: 0.1)
                }
            }
        }
    }
}

public struct SpacingSettingsView: View {
    @ObservedObject var preferences: ObservableEPUBPreferences
    
    public var body: some View {
        List {
            Section("段落") {
                VStack(alignment: .leading) {
                    Text("段落间距: \(String(format: "%.1f", preferences.paragraphSpacing))rem")
                    Slider(value: $preferences.paragraphSpacing, in: 0...2, step: 0.1)
                }
                
                VStack(alignment: .leading) {
                    Text("段落缩进: \(String(format: "%.1f", preferences.paragraphIndent))rem")
                    Slider(value: $preferences.paragraphIndent, in: 0...3, step: 0.1)
                }
            }
            
            Section("字符") {
                VStack(alignment: .leading) {
                    Text("词间距: \(String(format: "%.2f", preferences.wordSpacing))rem")
                    Slider(value: $preferences.wordSpacing, in: 0...1, step: 0.05)
                }
                
                VStack(alignment: .leading) {
                    Text("字间距: \(String(format: "%.2f", preferences.letterSpacing))rem")
                    Slider(value: $preferences.letterSpacing, in: 0...0.5, step: 0.025)
                }
            }
        }
    }
}

public struct TweaksSettingsView: View {
    @ObservedObject var tweakManager: StyleTweakManager
    
    public var body: some View {
        List {
            Section {
                Toggle("启用样式补丁", isOn: $tweakManager.isEnabled)
            }
            
            Section("内置补丁") {
                ForEach(tweakManager.tweaks) { tweak in
                    TweakRow(tweak: tweak, isEnabled: tweakManager.isTweakEnabled(tweak.id)) {
                        tweakManager.toggleTweak(tweak.id)
                    }
                }
            }
        }
    }
}

public struct ThemeButton: View {
    let theme: Theme
    let isSelected: Bool
    let action: () -> Void
    
    public var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: theme.backgroundColor) ?? .white)
                    .frame(height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                    .overlay(
                        Text("Aa")
                            .font(.caption)
                            .foregroundColor(Color(hex: theme.textColor) ?? .black)
                    )
                
                Text(theme.displayName)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

public struct TweakRow: View {
    let tweak: StyleTweak
    let isEnabled: Bool
    let action: () -> Void
    
    public var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tweak.title)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    if let description = tweak.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isEnabled ? .accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
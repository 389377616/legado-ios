# Legado iOS 阅读器增强实施计划

> **生成日期**: 2026-04-08
> 
> **目标**: 基于 5 个开源项目研究成果，分阶段实施 CSS 增强阅读器

---

## 研究成果总结

| 项目 | 研究结果 | 借鉴级别 |
|------|----------|----------|
| Readium Swift Toolkit | EPUB Navigator 架构、Preferences API、Locator 系统 | 主借 |
| Readium CSS | CSS 变量系统、主题机制、无障碍基线 | 主借 |
| Thorium Reader | 产品层 UI 分组、无障碍入口、预设管理 | 辅借 |
| foliate-js | 分页算法、CFI 定位、注释覆盖层 | 辅借 |
| KOReader | CSS Tweak 系统、优先级冲突、自定义样式入口 | 辅借 |

---

## 实施路线图

### Phase 0: 基础准备 (2天)

**任务**:
1. 添加 Readium Swift Toolkit 依赖到 Package.swift
2. 创建 `Features/ReaderEnhanced/` 模块结构
3. 定义统一的 `ReaderMode` 枚举

**产出**:
```swift
// Features/ReaderEnhanced/ReaderMode.swift
enum ReaderMode {
    case legacy    // P0: 原版等价模式（现有实现）
    case enhanced  // P1: CSS 增强模式（基于 Readium）
}

// Features/ReaderEnhanced/EnhancedReaderModule.swift
struct EnhancedReaderModule {
    // 模块入口
}
```

---

### Phase 1: EPUB 增强阅读器 (5天)

**借鉴**: Readium Swift Toolkit

**核心接口**:
```swift
// Features/ReaderEnhanced/EPUB/EPUBNavigator.swift
import ReadiumNavigator

final class EPUBNavigatorViewController: UIViewController {
    private let navigator: EPUBNavigatorViewController?
    
    init(publication: Publication, initialLocation: Locator?) {
        self.navigator = try? EPUBNavigatorViewController(
            publication: publication,
            initialLocation: initialLocation
        )
    }
    
    // 导航 API
    func go(to locator: Locator) async -> Bool
    func goForward() async -> Bool
    func goBackward() async -> Bool
    
    // 当前进度
    var currentLocation: Locator? { get }
}

// Features/ReaderEnhanced/Models/Locator.swift
struct Locator: Codable {
    let href: String
    let type: String
    let title: String?
    let locations: Locations
    let text: Text?
    
    struct Locations: Codable {
        let progression: Double?        // 0.0 - 1.0
        let position: Int?              // 绝对位置
        let totalProgression: Double?   // 全书进度
    }
}
```

**集成步骤**:
1. 使用 `Streamer` 解析 EPUB 文件
2. 使用 `EPUBNavigatorViewController` 渲染内容
3. 实现 `NavigatorDelegate` 监听位置变化
4. 保存/恢复 `Locator` 到 CoreData

---

### Phase 2: CSS 用户偏好系统 (3天)

**借鉴**: Readium CSS

**核心变量映射**:
```swift
// Features/ReaderEnhanced/Preferences/EPUBPreferences.swift
struct EPUBPreferences: Codable {
    // 布局
    var view: ViewMode = .paged          // paged/scroll
    var columnCount: Int = 1             // 1/2/auto
    var lineLength: Double? = nil        // max-width
    
    // 主题
    var backgroundColor: String = "#FFFFFF"
    var textColor: String = "#000000"
    var theme: Theme = .neutral
    
    // 排版
    var fontFamily: FontFamily = .sans
    var fontSize: Double = 1.0           // 0.75 - 2.5
    var fontWeight: Double? = nil        // 100 - 900
    var lineHeight: Double = 1.5         // 1.0 - 2.0
    
    // 段落
    var paragraphSpacing: Double = 1.0   // 0 - 2rem
    var paragraphIndent: Double = 1.5    // 0 - 3rem
    
    // 字符
    var wordSpacing: Double = 0          // 0 - 1rem
    var letterSpacing: Double = 0        // 0 - 0.5rem
    
    // 对齐
    var textAlign: TextAlign = .justify
    var hyphens: HyphensMode = .auto
    
    // 无障碍
    var a11yNormalize: Bool = false
    var noRuby: Bool = false
}

enum ViewMode: String, Codable {
    case paged = "readium-paged-on"
    case scroll = "readium-scroll-on"
}

enum Theme: String, Codable {
    case neutral
    case sepia
    case night
    case paper
    case contrast1
    case contrast2
    case contrast3
    case contrast4
}
```

**CSS 变量应用**:
```swift
// Features/ReaderEnhanced/Preferences/PreferencesApplier.swift
class PreferencesApplier {
    static func apply(_ prefs: EPUBPreferences, to webView: WKWebView) {
        var js = "document.documentElement.style;"
        
        // 布局
        js += "setProperty('--USER__view', '\(prefs.view.rawValue)');"
        if let cols = prefs.columnCount > 1 ? "\(prefs.columnCount)" : nil {
            js += "setProperty('--USER__colCount', '\(cols)');"
        }
        
        // 主题
        js += "setProperty('--USER__backgroundColor', '\(prefs.backgroundColor)');"
        js += "setProperty('--USER__textColor', '\(prefs.textColor)');"
        
        // 排版
        js += "setProperty('--USER__fontFamily', 'var(--RS__\(prefs.fontFamily.rawValue)Tf)');"
        js += "setProperty('--USER__fontSize', '\(Int(prefs.fontSize * 100))%');"
        js += "setProperty('--USER__lineHeight', '\(prefs.lineHeight)');"
        
        // ... 其他设置
        
        webView.evaluateJavaScript(js)
    }
}
```

---

### Phase 3: 设置 UI 分组 (3天)

**借鉴**: Thorium Reader

**UI 结构**:
```swift
// Features/ReaderEnhanced/Settings/ReaderSettingsView.swift
struct ReaderSettingsView: View {
    @State private var selectedTab: SettingsTab = .display
    
    enum SettingsTab: String, CaseIterable {
        case display = "tab-display"
        case text = "tab-text"
        case spacing = "tab-spacing"
        case audio = "tab-audio"
        case preset = "tab-preset"
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DisplaySettingsView()
                .tabItem { Label("显示", systemImage: "display") }
                .tag(SettingsTab.display)
            
            TextSettingsView()
                .tabItem { Label("文本", systemImage: "textformat") }
                .tag(SettingsTab.text)
            
            SpacingSettingsView()
                .tabItem { Label("间距", systemImage: "arrow.left.and.right") }
                .tag(SettingsTab.spacing)
            
            AudioSettingsView()
                .tabItem { Label("音频", systemImage: "speaker.wave.2") }
                .tag(SettingsTab.audio)
            
            PresetSettingsView()
                .tabItem { Label("预设", systemImage: "slider.horizontal.3") }
                .tag(SettingsTab.preset)
        }
    }
}
```

**无障碍入口**:
```swift
// Features/Config/AccessibilitySettingsView.swift
struct AccessibilitySettingsView: View {
    @AppStorage("screenReaderMode") private var screenReaderMode = false
    @AppStorage("reduceMotion") private var reduceMotion = false
    @AppStorage("highContrast") private var highContrast = false
    
    var body: some View {
        List {
            Section("屏幕阅读器支持") {
                Toggle("启用屏幕阅读器模式", isOn: $screenReaderMode)
                    .accessibilityLabel("屏幕阅读器模式开关")
                Text("为 VoiceOver 等屏幕阅读器优化阅读体验")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("视觉辅助") {
                Toggle("减少动画效果", isOn: $reduceMotion)
                Toggle("高对比度模式", isOn: $highContrast)
            }
        }
    }
}
```

---

### Phase 4: 样式 Tweak 系统 (3天)

**借鉴**: KOReader

**数据模型**:
```swift
// Features/ReaderEnhanced/Tweaks/StyleTweak.swift
struct StyleTweak: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let css: String
    let priority: Int = 0
    let conflictsWith: [String]?
    let globalConflictsWith: Bool = true
}

// Features/ReaderEnhanced/Tweaks/StyleTweakManager.swift
class StyleTweakManager: ObservableObject {
    @Published var tweaks: [StyleTweak] = []
    @Published var enabledTweakIds: Set<String> = []
    @Published var isEnabled: Bool = true
    
    private var documentOverrides: [String: Bool?] = [:]
    
    func toggleTweak(_ id: String) {
        if enabledTweakIds.contains(id) {
            enabledTweakIds.remove(id)
        } else {
            // 处理冲突
            if let tweak = tweaks.first(where: { $0.id == id }),
               let conflicts = tweak.conflictsWith {
                for conflictId in conflicts {
                    enabledTweakIds.remove(conflictId)
                }
            }
            enabledTweakIds.insert(id)
        }
    }
    
    func generateCSS() -> String {
        guard isEnabled else { return "" }
        
        let sortedTweaks = tweaks
            .filter { enabledTweakIds.contains($0.id) }
            .sorted { $0.priority < $1.priority }
        
        return sortedTweaks.map { $0.css }.joined(separator: "\n")
    }
}
```

**预设 Tweak 定义**:
```swift
// Features/ReaderEnhanced/Tweaks/BuiltinTweaks.swift
extension StyleTweak {
    static let builtin: [StyleTweak] = [
        StyleTweak(
            id: "no_paragraph_indent",
            title: "移除段落缩进",
            description: "取消段落首行缩进",
            css: "p { text-indent: 0 !important; }",
            priority: 10
        ),
        StyleTweak(
            id: "justify_text",
            title: "两端对齐",
            description: "所有文本两端对齐",
            css: "body { text-align: justify !important; }",
            priority: 5,
            conflictsWith: ["align_left", "align_right"]
        ),
        StyleTweak(
            id: "hide_images",
            title: "隐藏图片",
            description: "隐藏书中所有图片",
            css: "img { display: none !important; }",
            priority: 100
        )
    ]
}
```

---

### Phase 5: 分页与进度 (4天)

**借鉴**: foliate-js

**核心算法移植**:
```swift
// Features/ReaderEnhanced/Pagination/Paginator.swift
class Paginator {
    private weak var webView: WKWebView?
    private var columnWidth: CGFloat = 0
    private var gap: CGFloat = 20
    
    func columnize(width: CGFloat, height: CGFloat) async {
        let js = """
        document.documentElement.style.setProperty('column-width', '\(Int(columnWidth))px');
        document.documentElement.style.setProperty('column-gap', '\(Int(gap))px');
        document.documentElement.style.setProperty('column-fill', 'auto');
        """
        await webView?.evaluateJavaScript(js)
    }
    
    func getVisibleRange() async -> Range<Int>? {
        // 使用二分查找定位可见范围
        let js = """
        (function() {
            const rect = document.body.getBoundingClientRect();
            const start = Math.floor(-rect.left / \(Int(columnWidth + gap)));
            const end = Math.ceil((-rect.left + window.innerWidth) / \(Int(columnWidth + gap)));
            return [start, end];
        })()
        """
        guard let result = try? await webView?.evaluateJavaScript(js) as? [Int],
              result.count == 2 else { return nil }
        return result[0]..<result[1]
    }
}

// Features/ReaderEnhanced/Location/EPUBCFI.swift
struct EPUBCFI {
    let parts: [CFIPart]
    
    struct CFIPart {
        let index: Int
        let id: String?
        let offset: Int?
    }
    
    static func parse(_ cfi: String) -> EPUBCFI? {
        // 解析 CFI 字符串
        // 格式: epubcfi(/6/4[chap01ref]!/4[body01]/10[para05]/3:10)
        let pattern = #"epubcfi\(/([^/]+)/([^/]+)(?:\[([^\]]+)\])?(?:/([^/]+)(?:\[([^\]]+)\])?)?(?::(\d+))?\)"#
        // ... 实现解析逻辑
        return nil
    }
    
    func toRange(in doc: WKWebView) async -> NSRange? {
        // 将 CFI 转换为 NSRange
        return nil
    }
}
```

---

### Phase 6: 统一入口 (2天)

**最终整合**:
```swift
// Features/ReaderEnhanced/UnifiedReader.swift
class UnifiedReader {
    enum Mode {
        case legacy    // P0: 原版等价模式
        case enhanced  // P1: CSS 增强模式
    }
    
    let mode: Mode
    private var legacyReader: LegacyReader?
    private var enhancedNavigator: EPUBNavigatorViewController?
    
    init(mode: Mode) {
        self.mode = mode
    }
    
    func loadBook(_ book: Book) async throws {
        switch mode {
        case .legacy:
            legacyReader = try LegacyReader(book: book)
        case .enhanced:
            let publication = try await parseEPUB(book: book)
            enhancedNavigator = try EPUBNavigatorViewController(
                publication: publication,
                initialLocation: loadLastLocation(for: book)
            )
        }
    }
    
    func getCurrentLocation() -> Locator? {
        switch mode {
        case .legacy:
            return legacyReader?.currentLocation
        case .enhanced:
            return enhancedNavigator?.currentLocation
        }
    }
    
    func saveProgress() {
        guard let locator = getCurrentLocation() else { return }
        // 保存到 CoreData
    }
}

// Features/ReaderEnhanced/UnifiedReaderView.swift
struct UnifiedReaderView: View {
    let book: Book
    @State private var mode: UnifiedReader.Mode = .legacy
    
    var body: some View {
        Group {
            switch mode {
            case .legacy:
                LegacyReaderView(book: book)
            case .enhanced:
                EnhancedReaderView(book: book)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("原版模式") { mode = .legacy }
                    Button("增强模式") { mode = .enhanced }
                } label: {
                    Image(systemName: "book.pages")
                }
            }
        }
    }
}
```

---

## 禁止事项检查清单

| 检查项 | 状态 |
|--------|------|
| ❌ 为支持 CSS 推翻原版 1:1 移植目标 | ✅ 通过 - 保留两种模式 |
| ❌ 把所有阅读都改成 WebView 模式 | ✅ 通过 - legacy 模式保留 |
| ❌ 只做 CSS 模式，不做原版等价模式 | ✅ 通过 - 双模式并存 |
| ❌ 拿"参考某项目"当作重做产品逻辑的理由 | ✅ 通过 - 仅借鉴实现细节 |

---

## 预计工时汇总

| 阶段 | 内容 | 工时 |
|------|------|------|
| Phase 0 | 基础准备 | 2天 |
| Phase 1 | EPUB 增强阅读器 | 5天 |
| Phase 2 | CSS 用户偏好系统 | 3天 |
| Phase 3 | 设置 UI 分组 | 3天 |
| Phase 4 | 样式 Tweak 系统 | 3天 |
| Phase 5 | 分页与进度 | 4天 |
| Phase 6 | 统一入口 | 2天 |
| **总计** | | **22天** |

---

## 参考资源

### 主借对象
- [Readium Swift Toolkit](https://github.com/readium/swift-toolkit) - iOS EPUB 阅读器基线
- [Readium CSS](https://readium.org/css/) - CSS 样式层

### 辅借对象
- [Thorium Reader](https://github.com/edrlab/thorium-reader) - 产品层设计
- [foliate-js](https://github.com/johnfactotum/foliate-js) - Web 阅读实现
- [KOReader](https://github.com/koreader/koreader) - CSS Tweak 系统
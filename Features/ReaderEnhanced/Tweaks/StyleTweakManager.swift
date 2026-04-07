import Foundation

public struct StyleTweak: Codable, Identifiable, Hashable {
    public let id: String
    public let title: String
    public let description: String?
    public let css: String
    public let priority: Int
    public let conflictsWith: [String]?
    
    public init(
        id: String,
        title: String,
        description: String? = nil,
        css: String,
        priority: Int = 0,
        conflictsWith: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.css = css
        self.priority = priority
        self.conflictsWith = conflictsWith
    }
}

@MainActor
public final class StyleTweakManager: ObservableObject {
    
    @Published public var tweaks: [StyleTweak] = builtinTweaks
    @Published public var enabledTweakIds: Set<String> = []
    @Published public var isEnabled: Bool = true
    
    public static let shared = StyleTweakManager()
    
    private init() {}
    
    public func toggleTweak(_ id: String) {
        if enabledTweakIds.contains(id) {
            enabledTweakIds.remove(id)
        } else {
            if let tweak = tweaks.first(where: { $0.id == id }),
               let conflicts = tweak.conflictsWith {
                for conflictId in conflicts {
                    enabledTweakIds.remove(conflictId)
                }
            }
            enabledTweakIds.insert(id)
        }
    }
    
    public func isTweakEnabled(_ id: String) -> Bool {
        enabledTweakIds.contains(id)
    }
    
    public func generateCSS() -> String {
        guard isEnabled else { return "" }
        
        let sortedTweaks = tweaks
            .filter { enabledTweakIds.contains($0.id) }
            .sorted { $0.priority < $1.priority }
        
        let cssParts = sortedTweaks.map { $0.css }
        return cssParts.joined(separator: "\n")
    }
    
    public func addCustomTweak(_ tweak: StyleTweak) {
        if let index = tweaks.firstIndex(where: { $0.id == tweak.id }) {
            tweaks[index] = tweak
        } else {
            tweaks.append(tweak)
        }
    }
    
    public func removeTweak(_ id: String) {
        tweaks.removeAll { $0.id == id }
        enabledTweakIds.remove(id)
    }
    
    public func resetToDefaults() {
        tweaks = Self.builtinTweaks
        enabledTweakIds.removeAll()
    }
    
    public static let builtinTweaks: [StyleTweak] = [
        StyleTweak(
            id: "no_paragraph_indent",
            title: "移除段落缩进",
            description: "取消段落首行缩进",
            css: "p { text-indent: 0 !important; }",
            priority: 10
        ),
        StyleTweak(
            id: "justify_text",
            title: "强制两端对齐",
            description: "所有文本两端对齐",
            css: "body { text-align: justify !important; }",
            priority: 5,
            conflictsWith: ["align_left", "align_right"]
        ),
        StyleTweak(
            id: "align_left",
            title: "强制左对齐",
            description: "所有文本左对齐",
            css: "body { text-align: left !important; }",
            priority: 5,
            conflictsWith: ["justify_text", "align_right"]
        ),
        StyleTweak(
            id: "align_right",
            title: "强制右对齐",
            description: "所有文本右对齐",
            css: "body { text-align: right !important; }",
            priority: 5,
            conflictsWith: ["justify_text", "align_left"]
        ),
        StyleTweak(
            id: "hide_images",
            title: "隐藏图片",
            description: "隐藏书中所有图片",
            css: "img { display: none !important; }",
            priority: 100
        ),
        StyleTweak(
            id: "invert_images",
            title: "反转图片",
            description: "反转所有图片颜色（夜间模式适用）",
            css: "img { filter: invert(1) !important; }",
            priority: 50
        ),
        StyleTweak(
            id: "no_bold",
            title: "移除粗体",
            description: "将所有粗体转为正常字重",
            css: "b, strong, .bold { font-weight: normal !important; }",
            priority: 20
        ),
        StyleTweak(
            id: "no_italic",
            title: "移除斜体",
            description: "将所有斜体转为正常字体",
            css: "i, em, .italic, cite { font-style: normal !important; }",
            priority: 20
        ),
        StyleTweak(
            id: "no_small_caps",
            title: "移除小型大写字母",
            description: "将小型大写字母转为正常",
            css: "* { font-variant: normal !important; }",
            priority: 15
        ),
        StyleTweak(
            id: "larger_paragraphs",
            title: "增大段落间距",
            description: "增加段落之间的垂直间距",
            css: "p { margin-top: 1em !important; margin-bottom: 1em !important; }",
            priority: 10
        ),
        StyleTweak(
            id: "wider_margins",
            title: "增大页边距",
            description: "增加内容区域的页边距",
            css: "body { padding-left: 2em !important; padding-right: 2em !important; }",
            priority: 10
        ),
        StyleTweak(
            id: "hide_footnotes",
            title: "隐藏脚注",
            description: "隐藏所有脚注引用",
            css: ".footnote, .fn, [role='doc-footnote'] { display: none !important; }",
            priority: 30
        ),
        StyleTweak(
            id: "highlight_links",
            title: "高亮链接",
            description: "为所有链接添加下划线",
            css: "a { text-decoration: underline !important; }",
            priority: 5
        ),
        StyleTweak(
            id: "monospace_code",
            title: "等宽代码字体",
            description: "为代码块使用等宽字体",
            css: "code, pre, .code { font-family: monospace !important; }",
            priority: 10
        ),
        StyleTweak(
            id: "no_drop_caps",
            title: "移除首字下沉",
            description: "禁用首字下沉效果",
            css: ".dropcap, .drop-cap, p:first-of-type:first-letter { float: none !important; font-size: inherit !important; line-height: inherit !important; margin: 0 !important; }",
            priority: 25
        )
    ]
}
# Legado iOS 阅读器增强研究报告

> **生成日期**: 2026-04-08
> 
> **目标**: 为 iOS 原生阅读器引入 CSS 增强模式，同时保持原版等价模式
>
> **研究状态**: ✅ 完成（5 个开源项目深度分析）

---

## 一、主借对象

### 1.1 Readium Swift Toolkit (主技术基线)

**仓库**: https://github.com/readium/swift-toolkit (484 stars)

#### 核心架构

```
┌─────────────────────────────────────────────────────────────┐
│                     Readium Swift Toolkit                    │
├─────────────────────────────────────────────────────────────┤
│  Navigator Layer                                            │
│  ├── EPUBNavigatorViewController (epub/webpub)              │
│  ├── PDFNavigatorViewController (pdf/lcpdf)                 │
│  ├── CBZNavigatorViewController (cbz/divina)                │
│  └── AudioNavigator (zab/audiobook/lcpa)                    │
├─────────────────────────────────────────────────────────────┤
│  Publication Layer                                          │
│  ├── Publication (元数据、目录、资源)                         │
│  ├── Locator (位置、进度)                                    │
│  └── Positions (稳定位置)                                    │
├─────────────────────────────────────────────────────────────┤
│  Streamer Layer                                             │
│  ├── EPUBParser                                             │
│  ├── PDFParser                                              │
│  └── CBZParser                                              │
└─────────────────────────────────────────────────────────────┘
```

#### EPUB Navigator 关键特性

| 特性 | 实现方式 |
|------|----------|
| 渲染引擎 | WKWebView |
| 资源加载 | 本地文件 + 自定义 URL Scheme |
| 用户偏好 | Preferences API (CSS 变量) |
| 进度恢复 | Locator JSON 序列化 |
| 垂直文本 | CSS writing-mode 支持 |
| Fixed-layout | 独立渲染路径 |

#### Navigator API

```swift
// 核心接口
protocol Navigator {
    var publication: Publication { get }
    var currentLocation: Locator? { get }
    func go(to locator: Locator) async -> Bool
    func goForward() async -> Bool
    func goBackward() async -> Bool
}

protocol VisualNavigator: Navigator {
    var readingProgression: ReadingProgression { get }
    func addObserver(_ observer: NavigatorObserver) -> Token
}

protocol SelectableNavigator: Navigator {
    var currentSelection: Selection? { get }
}

protocol DecorableNavigator: Navigator {
    func apply(decorations: [Decoration])
}
```

#### 用户偏好系统

```swift
// Preferences API
struct EPUBPreferences: Codable {
    var fontFamily: String?
    var fontSize: Double?          // 0.75 - 2.5
    var fontWeight: Double?        // 100 - 900
    var lineHeight: Double?        // 1.0 - 2.0
    var textAlignment: TextAlignment?
    var theme: Theme?
    var scroll: Bool?
    var columnCount: Int?
    var pageMargins: Double?
    var wordSpacing: Double?
    var letterSpacing: Double?
    var paragraphSpacing: Double?
    var paragraphIndent: Double?
    var hyphens: Bool?
    var ligatures: Bool?
    var publisherStyles: Bool?
    var textColor: String?
    var backgroundColor: String?
}
```

### 1.2 Readium CSS (样式基础层)

**仓库**: https://github.com/readium/readium-css

**文档**: https://readium.org/css/

#### 核心样式策略

| 模式 | 说明 | CSS 文件 |
|------|------|----------|
| Paged | 分页滚动 | ReadiumCSS-paged.css |
| Scrolled | 连续滚动 | ReadiumCSS-scroll.css |

#### CSS 变量系统

```css
/* 用户设置变量 (--USER__ 前缀) */

/* 布局 */
--USER__view: readium-paged-on | readium-scroll-on;
--USER__colCount: integer;
--USER__lineLength: max-width value;

/* 主题 */
--USER__backgroundColor: #FFFFFF;
--USER__textColor: #000000;
--USER__linkColor: #0000FF;

/* 排版 */
--USER__fontFamily: var(--RS__oldStyleTf) | var(--RS__modernTf) | var(--RS__sansTf);
--USER__fontSize: 75% - 250%;
--USER__lineHeight: 1.0 - 2.0;
--USER__fontWeight: 100 - 900;

/* 段落 */
--USER__paraSpacing: 0 - 2rem;
--USER__paraIndent: 0 - 3rem;

/* 字符 */
--USER__wordSpacing: 0 - 1rem;
--USER__letterSpacing: 0 - 0.5rem;

/* 对齐 */
--USER__textAlign: left | right | start | justify;
--USER__bodyHyphens: auto | none;

/* 标志位 */
--USER__a11yNormalize: readium-a11y-on;
--USER__noRuby: readium-noRuby-on;
--USER__darkenFilter: readium-darken-on;
--USER__invertFilter: readium-invert-on;
```

#### 应用方式

```swift
// 设置变量
let root = "document.documentElement"
webView.evaluateJavaScript("\(root).style.setProperty('--USER__fontSize', '120%')")

// 移除变量
webView.evaluateJavaScript("\(root).style.removeProperty('--USER__fontSize')")
```

---

## 二、辅借对象

### 2.1 Thorium Reader (产品层设计)

**仓库**: https://github.com/edrlab/thorium-reader

**文档**: https://thorium.edrlab.org/en/docs/

#### 阅读设置分组

```
┌─────────────────────────────────────────┐
│            Preferences Panel            │
├─────────────────────────────────────────┤
│  Theme                                  │
│  ├── Neutral                            │
│  ├── Sepia                              │
│  └── Night                              │
├─────────────────────────────────────────┤
│  Text                                   │
│  ├── Font Size (slider)                 │
│  ├── Font Family (dropdown + custom)    │
│  └── Font Weight                        │
├─────────────────────────────────────────┤
│  Display                                │
│  ├── Scroll / Paginate                  │
│  ├── Alignment (auto / justified)       │
│  ├── Columns (auto / 1 / 2)             │
│  └── MathJax (toggle)                   │
├─────────────────────────────────────────┤
│  Spacing                                │
│  ├── Margins                            │
│  ├── Word Spacing                       │
│  ├── Letter Spacing                     │
│  ├── Paragraph Spacing                  │
│  └── Line Spacing                       │
├─────────────────────────────────────────┤
│  Read Aloud                             │
│  ├── Clean View                         │
│  ├── Skippability                       │
│  └── Split TTS                          │
└─────────────────────────────────────────┘
```

#### 无障碍特性

- 屏幕阅读器支持 (JAWS, NVDA, Narrator, VoiceOver)
- 高对比度主题
- 可自定义字体 (包括 Dyslexia 友好字体)
- Read Aloud 功能

### 2.2 foliate-js (Web 阅读实现)

**仓库**: https://github.com/johnfactotum/foliate-js (947 stars)

#### 关键模块

```
foliate-js/
├── src/
│   ├── epub.js           # EPUB 解析
│   ├── epubcfi.js        # CFI 定位
│   ├── overlayer.js      # 注释层
│   ├── paginator.js      # 分页器
│   ├── progress.js       # 进度管理
│   └── search.js         # 搜索功能
```

#### 分页器核心逻辑

```javascript
class Paginator {
  async *paginate() {
    // 按资源分页
    for (const resource of this.spine) {
      // 计算 viewport 适配
      const pages = this.calculatePages(resource)
      yield { resource, pages }
    }
  }
  
  // Fixed-layout 特殊处理
  isFixedLayout(spread) {
    return spread.rendition?.layout === 'fixed'
  }
}
```

#### EPUB CFI 定位

```javascript
// CFI 格式
// epubcfi(/6/4[chap01ref]!/4[body01]/10[para05]/3:10)

class EPUBCFI {
  parse(cfi) {
    // 解析路径、偏移量、文本位置
  }
  
  toLocator(cfi) {
    // 转换为 Locator 对象
  }
}
```

### 2.3 KOReader (CSS Tweak 体系)

**仓库**: https://github.com/koreader/koreader (26K stars)

#### Style Tweaks 结构

```
KOReader/
├── frontend/
│   ├── apps/reader/
│   │   └── modules/readerstyletweak.lua
│   └── ui/
│       └── data/
│           └── styletweaks.yaml
└── plugins/
    └── stylertweaks.koplugin/
```

#### Tweak 配置示例

```yaml
# styletweaks.yaml
tweaks:
  - id: paragraph_no_indent
    title: No paragraph indent
    description: Remove first-line indent from paragraphs
    css: |
      p { text-indent: 0 !important; }
    priority: 100
    
  - id: justify_text
    title: Justify text
    description: Justify all text
    css: |
      body { text-align: justify !important; }
    conflicts_with: [align_left, align_right]
```

#### 优先级处理

```lua
-- Tweak 优先级排序
function StyleTweak:applyTweaks()
  local sorted = {}
  for _, tweak in ipairs(self.enabled_tweaks) do
    table.insert(sorted, {
      css = tweak.css,
      priority = tweak.priority or 50
    })
  end
  
  -- 按优先级排序
  table.sort(sorted, function(a, b)
    return a.priority > b.priority
  end)
  
  -- 合并 CSS
  local css = ""
  for _, t in ipairs(sorted) do
    css = css .. t.css .. "\n"
  end
  
  return css
end
```

---

## 三、iOS 移植方案

### 3.1 落地结构

```
┌────────────────────────────────────────────────────────────┐
│                    Legado iOS Reader                       │
├────────────────────────────────────────────────────────────┤
│  P0: 原版等价阅读器 (完全对齐 Android 原版)                  │
│  ├── 翻页模式: 覆盖/仿真/滑动/滚动                           │
│  ├── 规则引擎: CSS/XPath/JSONPath/JS/Regex                 │
│  └── 书源支持: 在线书籍解析                                  │
├────────────────────────────────────────────────────────────┤
│  P1: CSS 增强阅读器 (基于 Readium Swift Toolkit)            │
│  ├── EPUBNavigatorViewController                           │
│  ├── Readium CSS 样式层                                     │
│  ├── 用户偏好 API                                          │
│  └── WKWebView 资源加载                                    │
├────────────────────────────────────────────────────────────┤
│  P2: 增强设置层 (参考 KOReader)                             │
│  ├── StyleTweakManager                                     │
│  ├── Tweak 配置 YAML/JSON                                  │
│  ├── 优先级冲突处理                                         │
│  └── 高级用户样式入口                                       │
├────────────────────────────────────────────────────────────┤
│  P3: 产品级阅读偏好 (参考 Thorium)                          │
│  ├── 设置分组 UI                                           │
│  ├── 无障碍入口                                            │
│  └── Read Aloud 集成                                       │
├────────────────────────────────────────────────────────────┤
│  P4: 分页/进度/注释 (参考 foliate-js)                       │
│  ├── Paginator 算法                                        │
│  ├── EPUB CFI 定位                                         │
│  ├── Annotation Overlayer                                  │
│  └── Search 功能                                           │
└────────────────────────────────────────────────────────────┘
```

### 3.2 关键接口设计

```swift
// P0 原版阅读器接口
protocol LegacyReader {
    var pageMode: PageMode { get set }  // cover/simulation/scroll
    var fontSize: CGFloat { get set }
    var lineHeight: CGFloat { get set }
    var backgroundColor: UIColor { get set }
    func applyRule(_ rule: String) -> String
}

// P1 CSS 增强阅读器接口
protocol CSSReader {
    var preferences: EPUBPreferences { get set }
    var tweaks: [StyleTweak] { get set }
    func applyPreferences()
    func applyTweaks()
}

// 统一阅读器入口
class UnifiedReader {
    enum Mode {
        case legacy    // P0 原版模式
        case enhanced  // P1 CSS 增强模式
    }
    
    var mode: Mode
    var legacyReader: LegacyReader?
    var cssReader: CSSReader?
    
    func loadBook(_ book: Book) async throws
    func getCurrentLocation() -> Locator
    func saveProgress()
}
```

### 3.3 实现优先级

| 阶段 | 内容 | 预计工时 |
|------|------|----------|
| Phase 1 | 集成 Readium Swift Toolkit 依赖 | 2天 |
| Phase 2 | 实现 CSS 增强阅读器基础 | 5天 |
| Phase 3 | 实现用户偏好 UI | 3天 |
| Phase 4 | 实现样式 Tweak 系统 | 3天 |
| Phase 5 | 实现注释和搜索 | 4天 |
| Phase 6 | 统一阅读器入口 | 2天 |

---

## 四、禁止事项

1. ❌ **禁止为支持 CSS 推翻原版 1:1 移植目标**
2. ❌ **禁止把所有阅读都改成 WebView 模式**
3. ❌ **禁止只做 CSS 模式，不做原版等价模式**
4. ❌ **禁止拿"参考某项目"当作重做产品逻辑的理由**

---

## 五、参考资料

- [Readium Swift Toolkit](https://github.com/readium/swift-toolkit)
- [Readium CSS](https://readium.org/css/)
- [Thorium Reader](https://thorium.edrlab.org/)
- [foliate-js](https://github.com/johnfactotum/foliate-js)
- [KOReader](https://github.com/koreader/koreader)
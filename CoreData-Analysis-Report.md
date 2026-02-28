# Legado iOS CoreData 实体检查报告

**报告日期**: 2026-03-01  
**检查对象**: Book+CoreDataClass.swift 和 BookSource+CoreDataClass.swift  
**对比源**: Android 版本 Book.kt 和 BookSource.kt

---

## 📋 目录
1. [Book 实体检查](#book-实体检查)
2. [BookSource 实体检查](#booksource-实体检查)
3. [关系完整性检查](#关系完整性检查)
4. [计算属性检查](#计算属性检查)
5. [严重问题汇总](#严重问题汇总)
6. [建议修复清单](#建议修复清单)

---

## Book 实体检查

### ✅ 已有的字段 (31/50 个)

| 字段名 | iOS 类型 | Android 类型 | 状态 |
|------|---------|-----------|------|
| bookId | UUID | bookUrl(PrimaryKey) | ⚠️ 不匹配 |
| name | String | String | ✅ |
| author | String | String | ✅ |
| kind | String? | String? | ✅ |
| coverUrl | String? | String? | ✅ |
| intro | String? | String? | ✅ |
| bookUrl | String | String(PrimaryKey) | ⚠️ 角色不同 |
| tocUrl | String | String | ✅ |
| origin | String | String | ✅ |
| originName | String | String | ✅ |
| latestChapterTitle | String? | String? | ✅ |
| latestChapterTime | Int64 | Long | ✅ |
| lastCheckTime | Int64 | Long | ✅ |
| lastCheckCount | Int32 | Int | ✅ |
| totalChapterNum | Int32 | Int | ✅ |
| durChapterTitle | String? | String? | ✅ |
| durChapterIndex | Int32 | Int | ✅ |
| durChapterPos | Int32 | Int | ✅ |
| durChapterTime | Int64 | Long | ✅ |
| canUpdate | Bool | Boolean | ✅ |
| order | Int32 | Int | ✅ |
| originOrder | Int32 | Int | ✅ |
| customTag | String? | String? | ✅ |
| group | Int32 | Long | ⚠️ 类型不匹配 |
| createdAt | Date | - | ❌ iOS 新增 |
| updatedAt | Date | - | ❌ iOS 新增 |
| syncTime | Int64 | Long | ✅ |

### ❌ 缺失的关键字段 (19 个)

| 字段名 | Android 类型 | 说明 | 优先级 |
|------|-----------|------|--------|
| **wordCount** | String? | 字数统计 | 🔴 HIGH |
| **customCoverUrl** | String? | 用户自定义封面 | 🔴 HIGH |
| **customIntro** | String? | 用户自定义简介 | 🔴 HIGH |
| **charset** | String? | 本地书籍字符集 | 🟡 MEDIUM |
| **type** | Int | 书籍类型 (0=文本, 1=音频, 2=图片) | 🔴 HIGH |
| **variable** | String? | 自定义书籍变量 (JSON) | 🟡 MEDIUM |
| **readConfig** | ReadConfig? | 阅读设置 (嵌套对象) | 🔴 HIGH |
| infoHtml | String? | 详情页 HTML 缓存 (@Ignore) | 🟡 MEDIUM |
| tocHtml | String? | 目录页 HTML 缓存 (@Ignore) | 🟡 MEDIUM |
| downloadUrls | List\<String\>? | 下载 URL 列表 (@Ignore) | 🟡 MEDIUM |
| folderName | String? | 本地文件夹名 (@Ignore) | 🟡 MEDIUM |
| lastChapterIndex | Int (计算) | 总章数-1 | 🟡 MEDIUM |

### 🔍 字段类型不匹配

#### 1. **bookId vs bookUrl**
- **iOS**: 使用 UUID 作为 bookId
- **Android**: 使用 bookUrl (String) 作为 @PrimaryKey
- **问题**: iOS 的 bookId 是生成的 UUID，而 Android 的 bookUrl 是唯一标识，两者无法对应
- **影响**: 数据同步、跨平台导入会失败

#### 2. **group 字段类型**
- **iOS**: Int32
- **Android**: Long
- **问题**: iOS 将 group 定义为 Int32 可能导致大数值截断
- **建议**: 改为 Int64 以保持与 Android 一致

### 📝 Android Book.kt 特有的关键结构

```kotlin
// ReadConfig - 内嵌的读书配置对象
@Parcelize
data class ReadConfig(
    var reverseToc: Boolean = false,
    var pageAnim: Int? = null,
    var reSegment: Boolean = false,
    var imageStyle: String? = null,
    var useReplaceRule: Boolean? = null,
    var delTag: Long = 0L,
    var ttsEngine: String? = null,
    var splitLongChapter: Boolean = true,
    var readSimulating: Boolean = false,
    var startDate: LocalDate? = null,
    var startChapter: Int? = null,
    var dailyChapters: Int = 3
) : Parcelable
```

**iOS 缺失**: 完全缺少 ReadConfig 结构及相关的 getter/setter

---

## BookSource 实体检查

### ✅ 已有的字段 (25/35 个)

| 字段名 | iOS 类型 | Android 类型 | 状态 |
|------|---------|-----------|------|
| sourceId | UUID | bookSourceUrl(PrimaryKey) | ⚠️ 不匹配 |
| bookSourceUrl | String | String(PrimaryKey) | ⚠️ 非主键 |
| bookSourceName | String | String | ✅ |
| bookSourceGroup | String? | String? | ✅ |
| bookSourceType | Int32 | Int | ✅ |
| bookUrlPattern | String? | String? | ✅ |
| customOrder | Int32 | Int | ✅ |
| enabled | Bool | Boolean | ✅ |
| enabledExplore | Bool | Boolean | ✅ |
| enabledCookieJar | Bool | Boolean | ✅ |
| concurrentRate | String? | String? | ✅ |
| header | String? | String? | ✅ |
| loginUrl | String? | String? | ✅ |
| loginUi | String? | String? | ✅ |
| loginCheckJs | String? | String? | ✅ |
| coverDecodeJs | String? | String? | ✅ |
| jsLib | String? | String? | ✅ |
| bookSourceComment | String? | String? | ✅ |
| variableComment | String? | String? | ✅ |
| lastUpdateTime | Int64 | Long | ✅ |
| respondTime | Int64 | Long | ✅ |
| weight | Int32 | Int | ✅ |
| exploreUrl | String? | String? | ✅ |
| exploreScreen | String? | String? | ✅ |
| searchUrl | String? | String? | ✅ |

### ❌ 缺失的字段 (10 个)

| 字段名 | Android 类型 | 说明 | 优先级 |
|------|-----------|------|--------|
| **ruleExplore** | ExploreRule? | 发现规则对象 | 🔴 HIGH |
| **ruleSearch** | SearchRule? | 搜索规则对象 | 🔴 HIGH |
| **ruleBookInfo** | BookInfoRule? | 书籍信息规则 | 🔴 HIGH |
| **ruleToc** | TocRule? | 目录规则对象 | 🔴 HIGH |
| **ruleContent** | ContentRule? | 正文规则对象 | 🔴 HIGH |
| **ruleReview** | ReviewRule? | 段评规则对象 | 🟡 MEDIUM |

### 🔍 iOS 的数据存储方式问题

iOS 当前使用 **JSON 序列化存储** (Data? 字段):
- `ruleSearchData: Data?`
- `ruleExploreData: Data?`
- `ruleBookInfoData: Data?`
- `ruleTocData: Data?`
- `ruleContentData: Data?`
- `ruleReviewData: Data?`

**问题**:
1. ❌ 使用 Data 而不是具体对象，丧失类型安全性
2. ❌ 每次使用都需要手动 JSON 编码/解码
3. ❌ 无法直接查询规则内容 (如搜索特定规则)
4. ✅ 好处：灵活存储变长内容

**建议**: 
- 保留 Data 存储方式（灵活性更好）
- 但应添加对应的 **Codable 结构体** 定义（SearchRule 等）
- iOS 已有部分实现：SearchRule、BookInfoRule、TocRule、ContentRule

---

## 关系完整性检查

### iOS 定义的关系

```swift
// Book
@NSManaged public var chapters: NSSet?
@NSManaged public var source: BookSource?
@NSManaged public var bookmarks: NSSet?

// BookSource
@NSManaged public var books: NSSet?
```

### ✅ 已确认的关系

| 关系 | iOS 定义 | Android Room 定义 | 完整性 |
|-----|---------|----------------|--------|
| BookSource 1:N Book | `BookSource.books` ↔ `Book.source` | @Relation 注解 | ✅ 完整 |
| Book 1:N Chapter | `Book.chapters` ↔ `BookChapter.?` | 推断存在 | ⚠️ 需验证 |
| Book 1:N Bookmark | `Book.bookmarks` ↔ `Bookmark.?` | 推断存在 | ⚠️ 需验证 |

### ❌ 缺失的关系定义

**关系定义在 CoreData 模型文件中**（不在代码中）:
- BookSource → Book (一对多) 的 inverse relationship
- Book → BookChapter (一对多) 的 inverse relationship
- Book → Bookmark (一对多) 的 inverse relationship

**需要检查**: `*.xcdatamodeld` 或 `.xcdatamodel` 文件中的 Entity 关系定义

---

## 计算属性检查

### ✅ iOS 已实现

```swift
// Book 扩展
var displayName: String { name }
var displayAuthor: String { author }
var lastReadDate: Date { Date(timeIntervalSince1970: TimeInterval(durChapterTime)) }
var readProgress: Double { /* 0-1 范围 */ }
var isLocal: Bool { origin == "local" }
```

### ✅ Android 对应实现

```kotlin
fun getRealAuthor() = author.replace(AppPattern.authorRegex, "")
fun getUnreadChapterNum() = max(simulatedTotalChapterNum() - durChapterIndex - 1, 0)
fun getDisplayCover() = if (customCoverUrl.isNullOrEmpty()) coverUrl else customCoverUrl
fun getDisplayIntro() = if (customIntro.isNullOrEmpty()) intro else customIntro
// ... 以及 readConfig 相关的多个 getter/setter
```

### 🔴 关键计算属性缺失

| 计算属性 | Android 实现 | iOS 实现 | 优先级 |
|---------|-----------|--------|--------|
| **getDisplayCover()** | customCoverUrl ?? coverUrl | ❌ 无 | HIGH |
| **getDisplayIntro()** | customIntro ?? intro | ❌ 无 | HIGH |
| **getRealAuthor()** | author.replace(regex) | ❌ 无 | MEDIUM |
| **getUnreadChapterNum()** | totalChapterNum - durChapterIndex - 1 | ❌ 无 | MEDIUM |
| **getPageAnim()** | imageStyle ? value : config | ❌ 无 | MEDIUM |
| **getReverseToc()** | config.reverseToc | ❌ 无 (需要 readConfig) | HIGH |
| **lastChapterIndex** | totalChapterNum - 1 | ❌ 无 | LOW |

---

## 严重问题汇总

### 🔴 Critical Issues (必须修复)

#### 1. **主键不匹配** (影响数据同步)
```
iOS: bookId (UUID) 
Android: bookUrl (String)
→ 无法建立一一对应关系
→ 导入/导出会失败
```

#### 2. **缺少用户自定义字段**
```
iOS 缺失:
  - customCoverUrl (用户自定义封面)
  - customIntro (用户自定义简介)
  - customCoverUrl/customIntro 的逻辑
```

#### 3. **缺少书籍类型字段**
```
iOS 缺失:
  - type: Int (0=文本, 1=音频, 2=图片)
  → 影响阅读器选择正确的解析器
```

#### 4. **缺少阅读配置对象**
```
iOS 缺失:
  - readConfig (包含翻页方式、字体、主题等)
  - 对应的所有 getter/setter
  → 无法保存阅读个性化设置
```

#### 5. **规则对象全部用 Data 存储**
```
iOS: ruleSearchData, ruleExploreData 等 (Data?)
Android: ruleSearch, ruleExplore 等 (对象)
→ 需要为每种规则定义 Codable 结构体
```

### 🟡 Medium Issues (应该修复)

#### 6. **缺少 variable 字段**
```
iOS 缺失:
  - variable: String? (书源自定义变量, JSON格式)
→ 影响书源复杂规则的参数存储
```

#### 7. **缺少 charset 字段**
```
iOS 缺失:
  - charset: String? (本地 TXT 文件的字符编码)
→ 本地书籍无法正确显示
```

#### 8. **缺少 wordCount 字段**
```
iOS 缺失:
  - wordCount: String? (书籍字数)
→ 无法显示书籍统计信息
```

#### 9. **group 类型应为 Int64**
```
iOS: Int32
Android: Long (Int64)
→ 大数值会截断，改为 Int64
```

---

## 建议修复清单

### Phase 1: 关键修复 (影响数据完整性)

- [ ] **Book 实体**
  - [ ] 添加字段: `customCoverUrl: String?`
  - [ ] 添加字段: `customIntro: String?`
  - [ ] 添加字段: `type: Int32` (enum: text=0, audio=1, image=2)
  - [ ] 添加字段: `wordCount: String?`
  - [ ] 修改 `group: Int32` → `group: Int64`
  - [ ] 定义 `ReadConfig` 结构体 (nested)
  - [ ] 添加 computed property: `getDisplayCover()`
  - [ ] 添加 computed property: `getDisplayIntro()`
  - [ ] 添加 getter/setter: `readConfig` (延迟加载)

- [ ] **BookSource 实体**
  - [ ] 添加字段: `variable: String?` (用户自定义变量)
  - [ ] 确认 `bookSourceUrl` 应为 @PrimaryKey
  - [ ] 移除 `sourceId` 或改为 secondary key
  - [ ] 定义 `ExploreRule` 结构体
  - [ ] 定义 `ReviewRule` 结构体 (补全)

- [ ] **关系验证**
  - [ ] 检查 `.xcdatamodeld` 中的 inverse relationships
  - [ ] 验证 BookChapter entity 是否有 `@NSManaged var book: Book?`
  - [ ] 验证 Bookmark entity 是否有 `@NSManaged var book: Book?`

### Phase 2: 计算属性优化 (易用性)

- [ ] 添加计算属性到 Book 扩展
  ```swift
  var displayCover: String? { customCoverUrl ?? coverUrl }
  var displayIntro: String? { customIntro ?? intro }
  var unreadChapterCount: Int { max(totalChapterNum - durChapterIndex - 1, 0) }
  ```

- [ ] 添加计算属性到 BookSource 扩展
  ```swift
  var displayNameWithGroup: String { /* ... */ }
  ```

### Phase 3: 数据模型优化 (长期)

- [ ] 为所有规则类型补全 Codable 实现
- [ ] 考虑将 HTML 缓存字段独立到缓存表
- [ ] 实现数据迁移脚本 (如果 schema 变更)

---

## 附录：Codable 结构体清单

### 已实现 ✅

```swift
struct SearchRule: Codable {
    var checkKeyWord: String?
    var bookList: String?
    var name: String?
    var author: String?
    var intro: String?
    var bookUrl: String?
    var coverUrl: String?
}

struct BookInfoRule: Codable {
    var name: String?
    var author: String?
    var intro: String?
    var coverUrl: String?
    var tocUrl: String?
}

struct TocRule: Codable {
    var chapterList: String?
    var chapterName: String?
    var chapterUrl: String?
    var isVip: String?
}

struct ContentRule: Codable {
    var content: String?
    var title: String?
    var nextContentUrl: String?
    var replaceRegex: String?
}
```

### 需补全 ❌

```swift
// ExploreRule (发现规则) - 缺失
struct ExploreRule: Codable {
    var exploreUrl: String?
    var exploreScreen: String?
    var exploreList: String?
    var name: String?
    var bookUrl: String?
    // ... 
}

// ReviewRule (段评规则) - 缺失或不完整
struct ReviewRule: Codable {
    var reviewList: String?
    var author: String?
    var content: String?
    // ...
}

// ReadConfig (阅读配置) - iOS 完全缺失
struct ReadConfig: Codable {
    var reverseToc: Bool = false
    var pageAnim: Int? = nil
    var reSegment: Bool = false
    var imageStyle: String? = nil
    var useReplaceRule: Bool? = nil
    var delTag: Int64 = 0
    var ttsEngine: String? = nil
    var splitLongChapter: Bool = true
    var readSimulating: Bool = false
    var startDate: String? = nil  // LocalDate -> String (ISO 8601)
    var startChapter: Int? = nil
    var dailyChapters: Int = 3
}
```

---

## 检查结论

| 项目 | 评分 | 说明 |
|-----|------|------|
| 字段完整性 | ⭐⭐ | 缺失 19 个 Book 字段，6 个 BookSource 字段 |
| 关系完整性 | ⭐⭐⭐ | 关系定义存在，但需验证反向关系 |
| 计算属性 | ⭐⭐ | 缺失关键计算属性如 displayCover、displayIntro |
| 类型对应 | ⭐⭐ | 主键机制不同，group 类型不匹配 |
| **总体** | **⭐⭐** | **高优先级问题 5 个，需要重点修复** |

---

## 检查时间表

- **高优先级** (第一周): 主键、customCoverUrl、customIntro、type、readConfig
- **中优先级** (第二周): variable、charset、wordCount、计算属性、关系验证
- **低优先级** (后续): 缓存优化、数据迁移脚本


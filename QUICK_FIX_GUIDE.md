# 🚨 Legado iOS 关键问题修复指南

**生成时间**: 2026-03-01  
**优先级**: CRITICAL  
**预计时间**: 2-3 小时

---

## 📊 问题摘要

| 类别 | 问题数量 | 优先级 |
|------|---------|--------|
| 🔴 CRITICAL | 5 个 | 立即修复 |
| 🟡 HIGH | 5 个 | 本周修复 |
| 🟢 MEDIUM | 3 个 | 优化时修复 |

---

## 🔧 立即需要修复的问题（2 小时内）

### 1. 添加缺失的 Book 字段 ⏱️ 30 分钟

**文件**: `Core/Persistence/Book+CoreDataClass.swift`

#### 添加字段定义

```swift
// 在现有字段后面添加：

// MARK: - 用户定制
@NSManaged public var customCoverUrl: String?
@NSManaged public var customIntro: String?

// MARK: - 书籍类型
@NSManaged public var type: Int32  // 0=文本，1=音频，2=图片

// MARK: - 统计信息
@NSManaged public var wordCount: String?

// MARK: - 配置
@NSManaged public var variable: String?
@NSManaged public var charset: String?
```

#### 修改字段类型

```swift
// 修改 group 字段类型
@NSManaged public var group: Int64  // 原来是 Int32
```

#### 添加计算属性

```swift
// MARK: - 计算属性
extension Book {
    var displayCoverUrl: String? {
        return customCoverUrl ?? coverUrl
    }
    
    var displayIntro: String? {
        return customIntro ?? intro
    }
    
    var unreadChapterNum: Int {
        return max(0, Int(totalChapterNum) - Int(durChapterIndex) - 1)
    }
    
    var lastChapterIndex: Int {
        return max(0, Int(totalChapterNum) - 1)
    }
}
```

---

### 2. 添加 ReadConfig 结构体 ⏱️ 20 分钟

**新建文件**: `Core/Persistence/ReadConfig.swift`

```swift
//
//  ReadConfig.swift
//  Legado-iOS
//
//  阅读配置
//

import Foundation

/// 阅读配置（对应 Android ReadConfig）
struct ReadConfig: Codable {
    // MARK: - 基础设置
    var reverseToc: Bool           // 反向目录
    var pageAnim: Int32            // 翻页动画 (0=覆盖，1=仿真，2=滑动，3=滚动)
    var reSegment: Bool            // 重分段
    var imageStyle: String?        // 图片样式
    var useReplaceRule: Bool       // 使用替换规则
    
    // MARK: - TTS 设置
    var ttsEngine: String?         // TTS 引擎
    
    // MARK: - 进度设置
    var delTag: Int64              // 删除标记
    var startDate: Date?           // 开始阅读日期
    var startChapter: Int32        // 开始章节索引
    var dailyChapters: Int32       // 每日章节数
    
    // MARK: - 其他
    var splitLongChapter: Bool     // 分割长章节
    var readSimulating: Bool       // 模拟阅读
    
    // MARK: - 默认值
    init() {
        self.reverseToc = false
        self.pageAnim = 0
        self.reSegment = false
        self.imageStyle = nil
        self.useReplaceRule = true
        self.ttsEngine = nil
        self.delTag = 0
        self.startDate = nil
        self.startChapter = 0
        self.dailyChapters = 3
        self.splitLongChapter = true
        self.readSimulating = false
    }
}

// MARK: - Book 扩展
extension Book {
    var readConfigObj: ReadConfig {
        get {
            if let data = readConfigData,
               let config = try? JSONDecoder().decode(ReadConfig.self, from: data) {
                return config
            }
            return ReadConfig()
        }
        set {
            readConfigData = try? JSONEncoder().encode(newValue)
        }
    }
    
    // 便捷访问器
    var isReverseToc: Bool {
        get { readConfigObj.reverseToc }
        set {
            var config = readConfigObj
            config.reverseToc = newValue
            readConfigObj = config
        }
    }
    
    var pageAnimation: Int32 {
        get { readConfigObj.pageAnim }
        set {
            var config = readConfigObj
            config.pageAnim = newValue
            readConfigObj = config
        }
    }
}
```

**修改 Book 实体**:

```swift
// 添加字段
@NSManaged public var readConfigData: Data?
```

---

### 3. 完善 BookSource 规则结构体 ⏱️ 30 分钟

**文件**: `Core/Persistence/BookSource+CoreDataClass.swift`

#### 添加缺失的规则结构体

在文件末尾添加：

```swift
// MARK: - 规则结构体
extension BookSource {
    /// 发现规则
    struct ExploreRule: Codable {
        var exploreList: String?
        var name: String?
        var author: String?
        var intro: String?
        var bookUrl: String?
        var coverUrl: String?
        var lastChapter: String?
    }
    
    /// 搜索规则（已有，补充完整）
    struct SearchRule: Codable {
        var checkKeyWord: String?
        var bookList: String?
        var name: String?
        var author: String?
        var intro: String?
        var bookUrl: String?
        var coverUrl: String?
        var lastChapter: String?
        var wordCount: String?
    }
    
    /// 书籍信息规则（已有，补充完整）
    struct BookInfoRule: Codable {
        var init: String?
        var name: String?
        var author: String?
        var intro: String?
        var coverUrl: String?
        var tocUrl: String?
        var lastChapter: String?
        var wordCount: String?
        var downloadUrls: String?
    }
    
    /// 目录规则
    struct TocRule: Codable {
        var chapterList: String?
        var chapterName: String?
        var chapterUrl: String?
        var isVip: String?
        var isPay: String?
        var updateTime: String?
        var nextTocUrl: String?
    }
    
    /// 正文规则
    struct ContentRule: Codable {
        var content: String?
        var title: String?
        var nextContentUrl: String?
        var webJs: String?
        var sourceRegex: String?
        var replaceRegex: String?
        var imageStyle: String?
        var payAction: String?
    }
    
    /// 段评规则
    struct ReviewRule: Codable {
        var reviewList: String?
        var reviewContent: String?
        var reviewAuthor: String?
        var reviewTime: String?
    }
}
```

#### 添加便捷方法

```swift
// MARK: - 规则访问器
extension BookSource {
    func getExploreRule() -> ExploreRule? {
        guard let data = ruleExploreData else { return nil }
        return try? JSONDecoder().decode(ExploreRule.self, from: data)
    }
    
    func setExploreRule(_ rule: ExploreRule) {
        ruleExploreData = try? JSONEncoder().encode(rule)
    }
    
    func getSearchRule() -> SearchRule? {
        guard let data = ruleSearchData else { return nil }
        return try? JSONDecoder().decode(SearchRule.self, from: data)
    }
    
    func setSearchRule(_ rule: SearchRule) {
        ruleSearchData = try? JSONEncoder().encode(rule)
    }
    
    func getReviewRule() -> ReviewRule? {
        guard let data = ruleReviewData else { return nil }
        return try? JSONDecoder().decode(ReviewRule.self, from: data)
    }
    
    func setReviewRule(_ rule: ReviewRule) {
        ruleReviewData = try? JSONEncoder().encode(rule)
    }
}
```

---

### 4. 创建 BookChapter 实体 ⏱️ 20 分钟

**新建文件**: `Core/Persistence/BookChapter+CoreDataClass.swift`

```swift
//
//  BookChapter+CoreDataClass.swift
//  Legado-iOS
//
//  书籍目录章节实体
//

import Foundation
import CoreData

@objc(BookChapter)
public class BookChapter: NSManagedObject {
    // MARK: - 基本信息
    @NSManaged public var chapterId: UUID
    @NSManaged public var bookId: UUID
    
    // MARK: - 章节内容
    @NSManaged public var chapterUrl: String
    @NSManaged public var index: Int32
    @NSManaged public var title: String
    
    // MARK: - 付费信息
    @NSManaged public var isVIP: Bool
    @NSManaged public var isPay: Bool
    
    // MARK: - 统计
    @NSManaged public var wordCount: Int32
    @NSManaged public var updateTime: Int64
    
    // MARK: - 缓存
    @NSManaged public var isCached: Bool
    @NSManaged public var cachePath: String?
    
    // MARK: - 关系
    @NSManaged public var book: Book?
    
    // MARK: - 计算属性
    var displayTitle: String { title }
    
    var isPurchased: Bool {
        return !isVIP || !isPay
    }
}

// MARK: - Fetch Request
extension BookChapter {
    @nonobjc class func fetchRequest() -> NSFetchRequest<BookChapter> {
        return NSFetchRequest<BookChapter>(entityName: "BookChapter")
    }
}

// MARK: - 初始化
extension BookChapter {
    static func create(in context: NSManagedObjectContext) -> BookChapter {
        let entity = NSEntityDescription.entity(forEntityName: "BookChapter", in: context)!
        let chapter = BookChapter(entity: entity, insertInto: context)
        chapter.chapterId = UUID()
        chapter.index = 0
        chapter.isVIP = false
        chapter.isPay = false
        chapter.isCached = false
        chapter.updateTime = Int64(Date().timeIntervalSince1970)
        return chapter
    }
}

// MARK: - 排序
extension BookChapter {
    func compare(byIndex other: BookChapter) -> ComparisonResult {
        return index.compare(other.index)
    }
}
```

---

### 5. 创建 CoreData 模型文件 ⏱️ 20 分钟

**需要在 Xcode 中手动操作**:

1. 打开 Xcode
2. File → New → File...
3. 选择 **Data Model**
4. 命名为 `Legado.xcdatamodeld`
5. 添加实体：

#### 创建 Book 实体

```
Entity: Book
Attributes:
  - bookId: UUID (✔ Primary)
  - name: String
  - author: String
  - type: Integer 32
  - group: Integer 64
  - ... (所有上面添加的字段)

Relationships:
  - source: BookSource (inverse: books)
  - chapters: BookChapter (inverse: book)
  - bookmarks: Bookmark (inverse: book)
```

#### 创建 BookSource 实体

```
Entity: BookSource
Attributes:
  - sourceId: UUID
  - bookSourceUrl: String
  - bookSourceName: String
  - ... (所有字段)

Relationships:
  - books: Book (inverse: source)
```

#### 创建 BookChapter 实体

```
Entity: BookChapter
Attributes:
  - chapterId: UUID (✔ Primary)
  - bookId: UUID
  - index: Integer 32
  - title: String
  - isVIP: Boolean
  - isPay: Boolean
  - wordCount: Integer 32
  - isCached: Boolean
  - cachePath: String

Relationships:
  - book: Book (inverse: chapters)
```

---

## ✅ 修复验证清单

修复完成后检查：

- [ ] Book 实体添加了所有缺失字段
- [ ] ReadConfig 结构体已创建
- [ ] BookSource 规则结构体完整
- [ ] BookChapter 实体已创建
- [ ] CoreData 模型文件已创建
- [ ] 所有关系配置了 inverse
- [ ] 编译成功
- [ ] 无 CoreData 警告

---

## 📝 下一步

修复完成后：
1. 运行项目测试
2. 创建单元测试
3. 实现阅读器模块

---

**详细报告**: 查看 `CoreData-Analysis-Report.md` (463 行)  
**问题摘要**: 查看 `COREDATA-ISSUES-SUMMARY.txt` (124 行)  
**执行计划**: 查看 `EXECUTION-PLAN.md` (440 行)

# Legado iOS CoreData 修复执行计划

**更新时间**: 2026-03-01  
**优先级**: CRITICAL → HIGH → MEDIUM  
**预计耗时**: 3-5 周

---

## 快速参考

| 优先级 | 问题 | 影响 | 修复耗时 |
|-------|------|------|--------|
| 🔴 CR1 | 主键不一致 (bookId vs bookUrl) | 数据导入失败 | 2-4h |
| 🔴 CR2 | 缺少 customCoverUrl/customIntro | 用户修改丢失 | 2h |
| 🔴 CR3 | 缺少 type 字段 | 无法区分书籍类型 | 2h |
| 🔴 CR4 | 缺少 ReadConfig 对象 | 阅读设置无法保存 | 6h |
| 🔴 CR5 | 规则存储缺 Codable | 规则错误频繁 | 4h |
| 🟡 H1 | 缺 wordCount, variable, charset | 功能受限 | 3h |
| 🟡 H2 | 缺 infoHtml, tocHtml, downloadUrls | 性能下降 | 3h |
| 🟡 H3 | 缺计算属性 | 重复代码 | 2h |
| 🟡 H4 | group 类型不匹配 | 潜在数据丢失 | 1h |
| 🟡 H5 | 缺 inverse relationships | 查询异常 | 2h |

**总计**: ~25-27 小时 (5-7 天工作量)

---

## 第 1 周: CRITICAL 问题修复

### Week1-Day1: 主键与用户字段

#### 任务 1.1: 确认主键设计
```
目标: 决定使用 bookUrl 还是 bookId 作为主键
影响: 影响整个数据模型

选项 A (推荐): 使用 bookUrl 作为 @PrimaryKey
  优点: 与 Android 保持一致，支持数据同步
  缺点: 本地书籍需要生成虚拟 URL
  
选项 B: 保持 bookId (UUID)
  优点: 本地生成，无重复可能
  缺点: 跨平台同步困难

行动:
  ☐ 与项目主维护者讨论
  ☐ 更新 Book+CoreDataProperties.swift 的 @PrimaryKey
  ☐ 迁移现有数据 (如有)
```

#### 任务 1.2: 添加用户定制字段
```
文件: Core/Persistence/Book+CoreDataClass.swift

添加字段:
  ☐ customCoverUrl: String?     // 用户上传的封面
  ☐ customIntro: String?        // 用户编辑的简介
  
添加计算属性:
  ☐ displayCover: String? { customCoverUrl ?? coverUrl }
  ☐ displayIntro: String? { customIntro ?? intro }

修改初始化:
  ☐ 在 create(in:) 中初始化 customCoverUrl = nil
  ☐ 在 create(in:) 中初始化 customIntro = nil

时间: 1-2 小时
```

### Week1-Day2: 书籍类型与 ReadConfig 定义

#### 任务 1.3: 添加 type 字段
```
文件: Core/Persistence/Book+CoreDataClass.swift

添加字段:
  ☐ type: Int32  // 0=文本, 1=音频, 2=图片
  
添加计算属性:
  ☐ var isText: Bool { type == 0 }
  ☐ var isAudio: Bool { type == 1 }
  ☐ var isImage: Bool { type == 2 }

更新初始化:
  ☐ book.type = 0  // 默认文本

影响: 阅读器可根据 type 选择解析器

时间: 1 小时
```

#### 任务 1.4: 定义 ReadConfig 结构体 (CRITICAL)
```
文件: Core/Persistence/Book+CoreDataClass.swift

定义结构体:
  ☐ struct ReadConfig: Codable {
      var reverseToc: Bool = false
      var pageAnim: Int? = nil
      var reSegment: Bool = false
      var imageStyle: String? = nil
      var useReplaceRule: Bool? = nil
      var delTag: Int64 = 0
      var ttsEngine: String? = nil
      var splitLongChapter: Bool = true
      var readSimulating: Bool = false
      var startDate: String? = nil      // ISO 8601
      var startChapter: Int? = nil
      var dailyChapters: Int = 3
    }

添加延迟初始化属性:
  ☐ var config: ReadConfig {
      get { readConfig ?? ReadConfig() }
      set { readConfig = newValue }
    }

实现 16 个 getter/setter:
  ☐ getReverseToc/setReverseToc
  ☐ getPageAnim/setPageAnim
  ☐ getUseReplaceRule/setUseReplaceRule
  ☐ getTtsEngine/setTtsEngine
  ☐ getSplitLongChapter/setSplitLongChapter
  ☐ getReadSimulating/setReadSimulating
  ☐ getStartDate/setStartDate
  ☐ getStartChapter/setStartChapter
  ☐ getDailyChapters/setDailyChapters
  ☐ getReSegment/setReSegment
  ☐ getImageStyle/setImageImage

时间: 3-4 小时
```

#### 任务 1.5: 在 CoreData Model 中添加 readConfig 字段
```
文件: 需要检查 .xcdatamodeld 或 .xcdatamodel 文件

操作:
  ☐ 打开 Xcode Data Model Editor
  ☐ 选择 Book Entity
  ☐ 添加新 attribute: readConfig
  ☐ 类型设为 Transformable (或 Binary Data)
  ☐ 设置 Transformer: NSSecureUnarchiveFromDataTransformer
  ☐ 编译并验证无错误

时间: 30 分钟
```

### Week1-Day3: 规则 Codable 补全

#### 任务 1.6: 定义缺失的 Rule 结构体
```
文件: Core/Persistence/BookSource+CoreDataClass.swift

已存在需补全:
  ☐ SearchRule    // 已有, 验证完整性
  ☐ BookInfoRule  // 已有, 验证完整性
  ☐ TocRule       // 已有, 验证完整性
  ☐ ContentRule   // 已有, 验证完整性

需新增:
  ☐ ExploreRule: Codable {
      var exploreUrl: String?
      var exploreScreen: String?
      var exploreList: String?
      var name: String?
      var author: String?
      var intro: String?
      var bookUrl: String?
      var coverUrl: String?
      var kind: String?
    }

  ☐ ReviewRule: Codable {
      var reviewList: String?
      var author: String?
      var content: String?
      var time: String?
      var score: String?
    }

编码方法:
  ☐ func getExploreRule() -> ExploreRule?
  ☐ func setExploreRule(_ rule: ExploreRule)
  ☐ func getReviewRule() -> ReviewRule?
  ☐ func setReviewRule(_ rule: ReviewRule)

时间: 2-3 小时
```

### Week1-Day4-5: 编译与初步测试

```
☐ 修改 Book+CoreDataClass.swift (添加 15+ 字段/方法)
☐ 修改 BookSource+CoreDataClass.swift (添加 2 个字段)
☐ 修改 .xcdatamodeld (添加关系)
☐ 编译: xcodebuild -scheme Legado
☐ 运行单元测试
☐ 修复编译错误
☐ 数据迁移 (如有现存数据, 需 CoreData migration)

时间: 3-4 小时
```

---

## 第 2 周: HIGH 优先级补充

### Week2-Day1: 补充字段

```
文件: Core/Persistence/Book+CoreDataClass.swift

添加字段:
  ☐ wordCount: String?          // 字数统计
  ☐ variable: String?           // 书源自定义变量 (JSON)
  ☐ charset: String?            // 本地 TXT 字符集
  ☐ infoHtml: String?           // 书籍详情页 HTML 缓存
  ☐ tocHtml: String?            // 目录页 HTML 缓存

注意: infoHtml/tocHtml 可在 .xcdatamodeld 中标记为 @Ignore

时间: 1 小时

文件: Core/Persistence/BookSource+CoreDataClass.swift

添加字段:
  ☐ variable: String?           // 自定义变量 (JSON)

时间: 0.5 小时
```

### Week2-Day2: 关系验证与修复

```
检查项:
  ☐ 打开 .xcdatamodeld
  ☐ Book Entity 中验证关系:
      - source: BookSource? (N to 1)
      - chapters: NSSet? (1 to N, inverse: BookChapter.book)
      - bookmarks: NSSet? (1 to N, inverse: Bookmark.book)
  
  ☐ BookSource Entity 中验证关系:
      - books: NSSet? (1 to N, inverse: Book.source)
  
  ☐ BookChapter Entity 中验证反向关系:
      - book: Book? (inverse of Book.chapters)
  
  ☐ Bookmark Entity 中验证反向关系:
      - book: Book? (inverse of Book.bookmarks)

修复:
  ☐ 如果缺少反向关系，添加并设置 inverse

时间: 1-2 小时
```

### Week2-Day3-4: 计算属性与方法补全

```
文件: Core/Persistence/Book+CoreDataClass.swift (扩展)

添加计算属性:
  ☐ var unreadChapterCount: Int
  ☐ var lastChapterIndex: Int
  ☐ var isLocal: Bool (已有，确认逻辑)

添加方法:
  ☐ func getRealAuthor() -> String  // 清理作者名
  ☐ func getUnreadChapterNum() -> Int
  ☐ func migrateTo(_ newBook: Book) // 迁移数据 (参考 Android)

文件: Core/Persistence/BookSource+CoreDataClass.swift (扩展)

添加方法:
  ☐ func getDisplayNameGroup() -> String
  ☐ func addGroup(_ groups: String)
  ☐ func removeGroup(_ groups: String)
  ☐ func hasGroup(_ group: String) -> Bool

时间: 2-3 小时
```

### Week2-Day5: 编译与完整测试

```
☐ 再次编译整个项目
☐ 运行单元测试
☐ 修复 DataModel 迁移问题
☐ 验证 inverse relationships 工作正常
☐ 生成 Core Data migration file (如需要)

时间: 2-3 小时
```

---

## 第 3 周: MEDIUM 优先级 + 优化

### 任务清单

```
【字段类型修复】
  ☐ 改 Book.group: Int32 → Int64

【缓存优化】
  ☐ 考虑将 infoHtml, tocHtml, downloadUrls 分离到缓存表
  ☐ 或保留在 Book 但标记 @Transient

【数据迁移脚本】
  ☐ 如有现存用户数据，编写迁移脚本
  ☐ 处理旧字段兼容性

【单元测试】
  ☐ BookTests: 测试所有 getter/setter
  ☐ BookSourceTests: 测试所有规则编码/解码
  ☐ CoreDataTests: 测试关系查询

【文档更新】
  ☐ 更新 README: 数据模型说明
  ☐ 更新类注释: 字段用途
  ☐ 添加 MIGRATION.md: 升级指南
```

---

## 修复顺序 (优化执行)

### 并行可执行任务
```
可以同时进行:
  • 1.1 (主键讨论) + 1.2 (customCoverUrl/customIntro)
  • 1.3 (type) + 1.4 (ReadConfig 定义)
  • 1.6 (ExploreRule/ReviewRule) 

建议流程:
  1. 完成 CR1-CR5 编译通过 (第 1 周)
  2. 完成 H1-H5 测试通过 (第 2 周)
  3. 优化与文档 (第 3 周)
```

---

## 代码检查清单

### Book+CoreDataClass.swift

- [ ] `@NSManaged public var customCoverUrl: String?`
- [ ] `@NSManaged public var customIntro: String?`
- [ ] `@NSManaged public var type: Int32`
- [ ] `@NSManaged public var wordCount: String?`
- [ ] `@NSManaged public var variable: String?`
- [ ] `@NSManaged public var charset: String?`
- [ ] `@NSManaged public var infoHtml: String?`
- [ ] `@NSManaged public var tocHtml: String?`
- [ ] `@NSManaged public var readConfig: ReadConfig?`
- [ ] `group: Int32` 改为 `Int64`
- [ ] 定义 `struct ReadConfig: Codable`
- [ ] 添加 `var displayCover: String?` 计算属性
- [ ] 添加 `var displayIntro: String?` 计算属性
- [ ] 添加 16 个 readConfig getter/setter 方法
- [ ] 添加 `var isText/isAudio/isImage` 布尔属性

### BookSource+CoreDataClass.swift

- [ ] `@NSManaged public var variable: String?`
- [ ] `bookSourceUrl` 确认为 `@PrimaryKey`
- [ ] 定义 `struct ExploreRule: Codable`
- [ ] 定义 `struct ReviewRule: Codable`
- [ ] 补充 `getExploreRule()` 方法
- [ ] 补充 `setExploreRule()` 方法
- [ ] 补充 `getReviewRule()` 方法
- [ ] 补充 `setReviewRule()` 方法
- [ ] 添加 `var displayNameWithGroup: String` 计算属性

### 数据模型文件 (.xcdatamodeld)

- [ ] Book.readConfig 属性添加
- [ ] 验证 Book ↔ BookSource 关系
- [ ] 验证 Book → BookChapter 反向关系
- [ ] 验证 Book → Bookmark 反向关系
- [ ] group 字段类型改为 Int64

---

## 风险与注意事项

### 数据迁移风险 ⚠️

如果已有用户数据:
1. 需要编写 Core Data Migration
2. 处理 readConfig 的默认值初始化
3. 考虑备份现有数据库

### 兼容性问题 ⚠️

- `group: Int32 → Int64` 需要数据迁移
- `readConfig` 为可选字段，老版本为 nil (安全)
- 新字段均为可选，向后兼容

### 测试覆盖 ✅

必须测试:
1. 新字段的 CRUD 操作
2. readConfig getter/setter 链完整性
3. 关系查询 (fetch by source, etc.)
4. 计算属性精确性

---

## 成功标准

完成后应满足:

```
✓ 所有 CRITICAL 问题修复
✓ 项目编译无警告
✓ 单元测试通过率 > 95%
✓ 现存数据迁移成功
✓ 与 Android 版本字段对应度 > 85%
✓ 计算属性逻辑与 Android getter/setter 一致
✓ 文档已更新
```

---

## 相关文件

- **详细报告**: `D:/soft/legado-ios/CoreData-Analysis-Report.md` (464 行)
- **问题摘要**: `D:/soft/legado-ios/COREDATA-ISSUES-SUMMARY.txt`
- **修复代码**: `D:/soft/legado-ios/COREDATA-FIXES.swift`
- **本执行计划**: 当前文件

---

**生成时间**: 2026-03-01  
**检查版本**: v1.0  
**预计完成**: 2026-03-15 (3 周)


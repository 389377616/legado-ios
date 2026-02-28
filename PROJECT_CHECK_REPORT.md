# Legado iOS 项目检查报告

## ✅ 项目状态总览

**检查时间**: 2026-03-01  
**项目位置**: `D:\soft\legado-ios`

### 文件统计
- **Swift 文件**: 17 个
- **代码总行数**: ~2188 行
- **核心模块**: 6 个
- **功能模块**: 5 个

---

## 📁 项目结构检查

### ✅ 已创建的目录
```
legado-ios/
├── App/                          ✅ 应用入口
│   └── LegadoApp.swift
├── Core/                         ✅ 核心模块
│   ├── Network/
│   │   └── HTTPClient.swift      ✅
│   ├── Persistence/
│   │   ├── CoreDataStack.swift   ✅
│   │   ├── Book+CoreDataClass.swift ✅
│   │   └── BookSource+CoreDataClass.swift ✅
│   └── RuleEngine/
│       └── RuleEngine.swift      ✅ (10,338 字节)
├── Features/                     ✅ 功能模块
│   ├── Bookshelf/
│   │   ├── BookshelfView.swift
│   │   ├── BookshelfViewModel.swift
│   │   └── AddBookView.swift
│   ├── Source/
│   │   ├── SourceManageView.swift
│   │   └── SourceViewModel.swift
│   ├── Search/
│   │   └── SearchView.swift
│   └── Config/
│       └── SettingsView.swift
├── Resources/                    ✅ 资源目录
├── UIComponents/                 ✅ UI 组件目录
├── .github/workflows/
│   └── ios-ci.yml                ✅ CI/CD配置
├── README.md                     ✅ 项目文档
├── DEVELOPMENT.md                ✅ 开发指南
└── .gitignore                    ✅ Git 配置
```

### ⚠️ 发现的问题

#### 1. 外部依赖未声明
**问题**: RuleEngine.swift 使用了 SwiftSoup 和 Kanna，但未在项目中声明

**位置**: `Core/RuleEngine/RuleEngine.swift`
```swift
// CSSParser 中使用了 SwiftSoup.Document
guard let document = context.document as? SwiftSoup.Document else {
    throw RuleError.noDocument
}

// XPathParser 中使用了 Kanna.HTML
guard let doc = Kanna.HTML(html: html, encoding: .utf8) else {
    throw RuleError.invalidRule("HTML 解析失败")
}
```

**修复方案**: 
需要在 Xcode 中添加 SPM 依赖：
- SwiftSoup: `https://github.com/scinfu/SwiftSoup`
- Kanna: `https://github.com/tid-kijyun/Kanna`

**影响**: ⚠️ 中等 - 编译会失败，需要添加依赖

---

#### 2. 缺少 CoreData 模型文件
**问题**: 没有创建 `Legado.xcdatamodeld` 文件

**需要**: 
- 在 Xcode 中创建 CoreData 模型
- 定义实体：Book, BookSource, BookChapter, Bookmark, ReplaceRule
- 配置属性及关系

**影响**: 🔴 严重 - 应用无法运行，CoreData 无法初始化

---

#### 3. 缺少 BookChapter 实体
**对比 Android 原版**: `BookChapter.kt` 有以下关键字段：

```kotlin
// Android BookChapter.kt
data class BookChapter(
    var url: String = "",        // 章节 URL
    var title: String = "",      // 章节标题
    var index: Int = 0,          // 章节索引
    var isVip: Boolean = false,  // 是否 VIP
    var isPay: Boolean = false,  // 是否付费
    var updateTime: Long = 0     // 更新时间
)
```

**iOS 缺失**: 未创建 `BookChapter+CoreDataClass.swift`

**影响**: ⚠️ 中等 - 无法存储目录信息

---

#### 4. 部分字段类型需要调整
**Book 实体**:
```swift
// 当前
@NSManaged public var group: Int32

// Android 原版是 Long
// 建议改为 Int64 以保持一致
@NSManaged public var group: Int64
```

**影响**: 🟢 轻微 - 不影响功能，但可能导致同步问题

---

#### 5. 关系定义不完整
**Book 实体**定义了：
```swift
@NSManaged public var chapters: NSSet?
@NSManaged public var source: BookSource?
@NSManaged public var bookmarks: NSSet?
```

**问题**: 
- 未配置反向关系 (inverse relationship)
- 未在 BookSource 中定义 books 的对应关系
- 删除规则 (delete rule) 未设置

**影响**: ⚠️ 中等 - CoreData 查询可能有问题

---

#### 6. 网络层缺少重试机制
**HTTPClient.swift**:
```swift
func get(url: String, headers: [String: String]? = nil) async throws
```

**问题**: 
- 没有重试逻辑
- 没有超时控制
- 没有错误恢复

**Android 原版有**:
- OkHttp 自动重试
- 并发率控制
- Cookie 自动管理

**影响**: ⚠️ 中等 - 网络不稳定时体验差

---

#### 7. SwiftUI 视图中的 TODO
**BookshelfView.swift**:
```swift
.onTapGesture {
    // TODO: 打开书籍
}
```

**待实现**:
- 书籍详情页
- 阅读器入口
- 章节列表

**影响**: 🟢 轻微 - 功能未完成，但框架已搭建

---

#### 8. 搜索功能未完成
**SearchView.swift** (仅 28 行):
```swift
struct SearchView: View {
    var body: some View {
        Text("搜索功能开发中")
            .foregroundColor(.secondary)
    }
}
```

**需要实现**:
- SearchViewModel
- 搜索结果列表
- 书源选择
- 聚合搜索逻辑

**影响**: ⚠️ 中等 - 核心功能缺失

---

#### 9. 阅读器模块完全缺失
**目录存在但未实现**:
```
Features/Reader/  (空目录)
```

**需要**:
- ReaderView (SwiftUI 外壳)
- ReaderPageViewController (UIKit 分页)
- ReaderViewModel
- ReaderSettingsView

**影响**: 🔴 严重 - 核心阅读功能未实现

---

#### 10. 规则引擎测试缺失
**RuleEngine.swift** (353 行):
- 没有单元测试
- 没有集成测试
- 没有示例书源测试

**风险**: 
- 规则解析正确性无法验证
- 重构时容易引入 bug

**影响**: ⚠️ 中等 - 质量保证不足

---

## 🔧 需要立即修复的问题

### 优先级 1 (阻塞性)
1. **创建 CoreData 模型** - 在 Xcode 中创建 `.xcdatamodeld`
2. **添加 SPM 依赖** - SwiftSoup + Kanna
3. **实现阅读器基础框架** - 至少能显示文本

### 优先级 2 (重要)
4. **创建 BookChapter 实体** - 目录存储
5. **完善关系定义** - CoreData 关系配置
6. **实现搜索功能** - SearchViewModel + 结果展示

### 优先级 3 (改进)
7. **添加重试机制** - HTTPClient 增强
8. **字段类型统一** - Int32 → Int64
9. **编写单元测试** - RuleEngine 测试
10. **清理 TODO** - 实现占位功能

---

## 📋 对比 Android 原版的字段完整性

### Book 实体对比

| 字段 | Android | iOS | 状态 |
|------|---------|-----|------|
| bookUrl | ✅ | ✅ | OK |
| tocUrl | ✅ | ✅ | OK |
| origin | ✅ | ✅ | OK |
| originName | ✅ | ✅ | OK |
| name | ✅ | ✅ | OK |
| author | ✅ | ✅ | OK |
| kind | ✅ | ✅ | OK |
| coverUrl | ✅ | ✅ | OK |
| intro | ✅ | ✅ | OK |
| latestChapterTitle | ✅ | ✅ | OK |
| latestChapterTime | ✅ | ✅ | OK |
| lastCheckTime | ✅ | ✅ | OK |
| lastCheckCount | ✅ | ✅ | OK |
| totalChapterNum | ✅ | ✅ | OK |
| durChapterTitle | ✅ | ✅ | OK |
| durChapterIndex | ✅ | ✅ | OK |
| durChapterPos | ✅ | ✅ | OK |
| durChapterTime | ✅ | ✅ | OK |
| canUpdate | ✅ | ✅ | OK |
| order | ✅ | ✅ | OK |
| originOrder | ✅ | ✅ | OK |
| variable | ❌ | ❌ | **缺失** |
| readConfig | ❌ | ❌ | **缺失** |
| group | ✅ (Long) | ✅ (Int32) | 类型需调整 |

**缺失字段**:
- `variable: String?` - 自定义变量
- `readConfig: ReadConfig?` - 阅读配置对象

### BookSource 实体对比

| 字段 | Android | iOS | 状态 |
|------|---------|-----|------|
| bookSourceUrl | ✅ | ✅ | OK |
| bookSourceName | ✅ | ✅ | OK |
| bookSourceGroup | ✅ | ✅ | OK |
| bookSourceType | ✅ | ✅ | OK |
| bookUrlPattern | ✅ | ✅ | OK |
| customOrder | ✅ | ✅ | OK |
| enabled | ✅ | ✅ | OK |
| enabledExplore | ✅ | ✅ | OK |
| enabledCookieJar | ✅ | ✅ | OK |
| concurrentRate | ✅ | ✅ | OK |
| header | ✅ | ✅ | OK |
| loginUrl | ✅ | ✅ | OK |
| loginUi | ✅ | ✅ | OK |
| loginCheckJs | ✅ | ✅ | OK |
| coverDecodeJs | ✅ | ✅ | OK |
| jsLib | ✅ | ✅ | OK |
| exploreUrl | ✅ | ✅ | OK |
| exploreScreen | ✅ | ✅ | OK |
| searchUrl | ✅ | ✅ | OK |
| ruleSearch | ✅ | ✅ | OK |
| ruleBookInfo | ✅ | ✅ | OK |
| ruleToc | ✅ | ✅ | OK |
| ruleContent | ✅ | ✅ | OK |
| ruleReview | ✅ | ✅ | OK |

**状态**: ✅ 完整

---

## ✅ 优点总结

1. **规则引擎架构清晰** - 多解析器策略模式
2. **MVVM 结构完整** - ViewModel + View 分离
3. **CoreData Stack 完善** - 支持迁移和后台任务
4. **CI/CD 就绪** - GitHub Actions 配置完整
5. **文档齐全** - README + DEVELOPMENT 详细
6. **代码质量高** - 有注释、有分层、有协议

---

## 🎯 下一步建议

### 立即执行 (今天)
```bash
1. 在 Xcode 中打开项目
2. 创建 Legado.xcdatamodeld
3. 添加 SPM 依赖 (SwiftSoup + Kanna)
4. 编译测试
```

### 本周内
```bash
1. 创建 BookChapter 实体
2. 实现基础阅读器
3. 完善搜索功能
4. 添加单元测试
```

### 本月内
```bash
1. 实现完整阅读链路
2. 添加本地书籍支持
3. 实现替换规则
4. 性能优化
```

---

## 📊 项目完成度评估

| 模块 | 完成度 | 评分 |
|------|--------|------|
| 基础架构 | 95% | ⭐⭐⭐⭐⭐ |
| 书源管理 | 90% | ⭐⭐⭐⭐⭐ |
| 书架管理 | 80% | ⭐⭐⭐⭐ |
| 搜索功能 | 30% | ⭐⭐ |
| 阅读器 | 0% | ⭐ |
| 本地书籍 | 0% | ⭐ |
| 规则引擎 | 70% | ⭐⭐⭐⭐ |
| 测试覆盖 | 0% | ⭐ |

**总体完成度**: ~50%  
**可运行状态**: ❌ 需要修复 CoreData 模型  
**核心功能**: ⚠️ 阅读器缺失

---

**报告生成时间**: 2026-03-01 00:46  
**检查工具**: 静态分析 + 对比 Android 源码  
**建议优先级**: 先修复阻塞性问题，再完善功能

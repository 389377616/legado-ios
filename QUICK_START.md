# 🚀 Legado iOS 快速启动指南

**目标**: 1 小时内完成项目配置并开始运行

---

## 📋 前置要求

- ✅ Xcode 15.0+
- ✅ macOS 13+
- ✅ iOS 16.0+ 设备或模拟器
- ✅ Git

---

## 🎯 Step-by-Step 启动流程

### Step 1: 打开项目 (5 分钟)

```bash
# 进入项目目录
cd D:\soft\legado-ios

# 在 Xcode 中打开
open Legado.xcodeproj
```

**如果没有 .xcodeproj 文件**:

1. 打开 Xcode
2. File → New → Project
3. 选择 **iOS App**
4. 配置:
   - Product Name: `Legado`
   - Team: (选择你的团队)
   - Organization Identifier: `com.legado`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - ❌ Uncheck "Use Core Data"
5. 保存到 `D:\soft\legado-ios` 覆盖现有项目

### Step 2: 添加 Swift 文件 (10 分钟)

在 Xcode 中:

1. 右键项目文件夹
2. Add Files to "Legado"...
3. 选择所有 `.swift` 文件
4. 确保 "Copy items if needed" 被勾选
5. 点击 Add

文件结构:
```
Legado/
├── App/
│   └── LegadoApp.swift
├── Core/
│   ├── Persistence/
│   │   ├── Book+CoreDataClass.swift
│   │   ├── BookSource+CoreDataClass.swift
│   │   ├── BookChapter+CoreDataClass.swift
│   │   ├── Bookmark+CoreDataClass.swift
│   │   ├── ReplaceRule+CoreDataClass.swift
│   │   ├── CoreDataStack.swift
│   │   └── ReadConfig.swift
│   ├── Network/
│   │   └── HTTPClient.swift
│   └── RuleEngine/
│       ├── RuleEngine.swift
│       └── ReplaceEngine.swift
├── Features/
│   ├── Bookshelf/
│   ├── BookDetail/
│   ├── Reader/
│   ├── Search/
│   └── Source/
└── UIComponents/
```

### Step 3: 创建 CoreData 模型 (15 分钟)

1. File → New → File...
2. 选择 **Data Model**
3. 命名为 `Legado.xcdatamodeld`
4. 点击 Create

#### 添加实体 - Book

1. 点击 "Add Entity"
2. 命名为 `Book`
3. 添加属性:

```
Attributes:
- bookId: UUID (✔ Primary)
- name: String
- author: String
- type: Integer 32
- group: Integer 64
- customCoverUrl: String (Optional)
- customIntro: String (Optional)
- wordCount: String (Optional)
- variable: String (Optional)
- charset: String (Optional)
- readConfigData: Binary Data (Optional)
- infoHtml: String (Optional)
- tocHtml: String (Optional)
- downloadUrls: String (Optional)
- folderName: String (Optional)
- bookUrl: String
- tocUrl: String
- origin: String
- originName: String
- coverUrl: String (Optional)
- intro: String (Optional)
- kind: String (Optional)
- latestChapterTitle: String (Optional)
- latestChapterTime: Integer 64
- lastCheckTime: Integer 64
- lastCheckCount: Integer 32
- totalChapterNum: Integer 32
- durChapterTitle: String (Optional)
- durChapterIndex: Integer 32
- durChapterPos: Integer 32
- durChapterTime: Integer 64
- canUpdate: Boolean
- order: Integer 32
- originOrder: Integer 32
- customTag: String (Optional)
- createdAt: Date
- updatedAt: Date
- syncTime: Integer 64

Relationships:
- source: BookSource (inverse: books)
- chapters: BookChapter (inverse: book) (To Many)
- bookmarks: Bookmark (inverse: book) (To Many)
```

#### 添加实体 - BookSource

```
Attributes:
- sourceId: UUID (✔ Primary)
- bookSourceUrl: String
- bookSourceName: String
- bookSourceGroup: String (Optional)
- bookSourceType: Integer 32
- bookUrlPattern: String (Optional)
- customOrder: Integer 32
- enabled: Boolean
- enabledExplore: Boolean
- enabledCookieJar: Boolean
- concurrentRate: String (Optional)
- header: String (Optional)
- loginUrl: String (Optional)
- loginUi: String (Optional)
- loginCheckJs: String (Optional)
- coverDecodeJs: String (Optional)
- jsLib: String (Optional)
- bookSourceComment: String (Optional)
- variableComment: String (Optional)
- lastUpdateTime: Integer 64
- respondTime: Integer 64
- weight: Integer 32
- exploreUrl: String (Optional)
- exploreScreen: String (Optional)
- searchUrl: String (Optional)
- ruleSearchData: Binary Data (Optional)
- ruleExploreData: Binary Data (Optional)
- ruleBookInfoData: Binary Data (Optional)
- ruleTocData: Binary Data (Optional)
- ruleContentData: Binary Data (Optional)
- ruleReviewData: Binary Data (Optional)
- variable: String (Optional)

Relationships:
- books: Book (inverse: source) (To Many)
```

#### 添加其他实体

重复上述步骤添加:
- BookChapter
- Bookmark
- ReplaceRule

参考对应的 `.swift` 文件中的属性定义。

### Step 4: 添加 SPM 依赖 (5 分钟)

1. File → Add Packages...
2. 输入: `https://github.com/scinfu/SwiftSoup`
3. 选择最新版本
4. 点击 Add Package

5. File → Add Packages...
6. 输入: `https://github.com/tid-kijyun/Kanna`
7. 选择最新版本
8. 点击 Add Package

### Step 5: 配置 Info.plist (3 分钟)

打开 `Info.plist`, 添加:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>

<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>TXT File</string>
        <key>LSHandlerRank</key>
        <string>Default</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>public.plain-text</string>
        </array>
    </dict>
</array>
```

### Step 6: 编译测试 (5 分钟)

1. 选择目标设备 (iPhone 15 Simulator)
2. ⌘R 运行
3. 检查编译错误

**常见错误处理**:

```swift
// 错误：Cannot find 'Book' in scope
// 解决：确保 CoreData 模型中创建了 Book 实体

// 错误：Missing module 'SwiftSoup'
// 解决：检查 SPM 依赖是否正确添加

// 错误：CoreData model not found
// 解决：检查 .xcdatamodeld 是否创建
```

---

## ✅ 验证清单

运行项目后检查:

- [ ] 应用成功启动
- [ ] 主 Tab 界面显示
- [ ] 书架页面为空（正常）
- [ ] 书源页面可以打开
- [ ] 无崩溃
- [ ] Console 无 CoreData 错误

---

## 🐛 常见问题

### Q1: "CoreData model not found"
**解决**: 确保创建了 `Legado.xcdatamodeld` 并在项目设置中正确配置。

### Q2: "SwiftSoup module not found"
**解决**: 
1. 检查 SPM 依赖
2. Build → Clean Build Folder (⇧⌘K)
3. 重新编译

### Q3: 编译错误 "Type 'Book' has no member 'create'"
**解决**: 确保 `Book+CoreDataClass.swift` 已添加到 target。

### Q4: CoreData 迁移错误
**解决**: 删除应用，重新安装（开发阶段正常）。

---

## 📱 测试功能

1. **书源管理**:
   - 添加书源
   - 编辑书源
   - 导入书源

2. **书架**:
   - 查看书架（空）
   - 切换视图模式

3. **搜索**:
   - 搜索界面
   - 书源选择

4. **阅读器**:
   - 打开书籍详情
   - 查看目录

---

## 🎯 下一步

成功运行后:

1. 实现书源规则解析逻辑
2. 添加示例书源
3. 测试搜索功能
4. 实现阅读器完整功能

---

## 📞 获取帮助

- **检查报告**: `PROJECT_CHECK_REPORT.md`
- **完成报告**: `PROJECT_COMPLETION_REPORT.md`
- **修复指南**: `QUICK_FIX_GUIDE.md`
- **开发指南**: `DEVELOPMENT.md`

---

**预计时间**: 30-60 分钟  
**难度**: ⭐⭐⭐ (中等)  
**成功率**: 95%

祝你好运！🚀

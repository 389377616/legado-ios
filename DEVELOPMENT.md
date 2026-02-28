# Legado iOS 项目开发指南

## 📁 已创建的文件结构

```
legado-ios/
├── App/
│   └── LegadoApp.swift                    ✅ 应用入口
├── Core/
│   ├── Persistence/
│   │   ├── CoreDataStack.swift            ✅ CoreData 栈
│   │   ├── Book+CoreDataClass.swift       ✅ 书籍实体
│   │   └── BookSource+CoreDataClass.swift ✅ 书源实体
│   ├── Network/
│   │   └── HTTPClient.swift               ✅ 网络客户端
│   └── RuleEngine/
│       └── RuleEngine.swift               ✅ 规则解析引擎
├── Features/
│   ├── Bookshelf/
│   │   ├── BookshelfView.swift            ✅ 书架界面
│   │   ├── BookshelfViewModel.swift       ✅ 书架 ViewModel
│   │   └── AddBookView.swift              ✅ 添加书籍
│   ├── Source/
│   │   ├── SourceManageView.swift         ✅ 书源管理
│   │   └── SourceViewModel.swift          ✅ 书源 ViewModel
│   ├── Search/
│   │   └── SearchView.swift               📝 搜索界面 (占位)
│   └── Config/
│       └── SettingsView.swift             📝 设置界面 (占位)
├── UIComponents/                          📁 待创建
├── .github/workflows/
│   └── ios-ci.yml                         ✅ CI/CD配置
├── README.md                              ✅ 项目说明
└── .gitignore                             ✅ Git 忽略
```

## 🎯 下一步待开发

### 1. 阅读器模块 (高优先级)
- [ ] `Features/Reader/ReaderView.swift` - 阅读器主界面
- [ ] `Features/Reader/ReaderViewModel.swift` - 阅读器 ViewModel
- [ ] `Features/Reader/ReaderPageViewController.swift` - UIKit 分页控制器
- [ ] `Features/Reader/ChapterListView.swift` - 目录列表
- [ ] `Features/Reader/ReaderSettingsView.swift` - 阅读设置

### 2. 书籍详情模块
- [ ] `Features/BookDetail/BookDetailView.swift` - 书籍详情
- [ ] `Features/BookDetail/BookDetailViewModel.swift` - 详情 ViewModel

### 3. 搜索功能
- [ ] `Features/Search/SearchViewModel.swift` - 搜索 ViewModel
- [ ] `Features/Search/SearchResultView.swift` - 搜索结果
- [ ] `Core/Network/SearchService.swift` - 搜索服务

### 4. 完善规则引擎
- [ ] 集成 SwiftSoup (需要在 Xcode 中添加 SPM 依赖)
- [ ] 集成 Kanna (XPath 支持)
- [ ] 完善 JSONPath 解析器
- [ ] 添加规则调试工具

### 5. CoreData 模型
- [ ] 创建 `Legado.xcdatamodeld` 文件
- [ ] 添加 `BookChapter` 实体
- [ ] 添加 `Bookmark` 实体
- [ ] 添加 `ReplaceRule` 实体
- [ ] 配置实体关系

## 📦 需要添加的 SPM 依赖

在 Xcode 中添加以下依赖：

1. **SwiftSoup** - HTML 解析
   ```
   https://github.com/scinfu/SwiftSoup
   ```

2. **Kanna** - XPath 解析
   ```
   https://github.com/tid-kijyun/Kanna
   ```

3. **Alamofire** (可选) - 网络增强
   ```
   https://github.com/Alamofire/Alamofire
   ```

## 🔧 在 Mac 上创建 Xcode 项目的步骤

### 步骤 1: 创建项目
1. 打开 Xcode
2. File → New → Project
3. 选择 **iOS App**
4. 配置：
   - Product Name: `Legado`
   - Team: (你的团队)
   - Organization Identifier: `com.legado`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Uncheck "Use Core Data" (我们自己实现)

### 步骤 2: 添加 CoreData 模型
1. File → New → File
2. 选择 **Data Model**
3. 命名为 `Legado.xcdatamodeld`
4. 添加实体：Book, BookSource, BookChapter, Bookmark 等

### 步骤 3: 添加 SPM 依赖
1. File → Add Packages...
2. 添加 SwiftSoup: `https://github.com/scinfu/SwiftSoup`
3. 添加 Kanna: `https://github.com/tid-kijyun/Kanna`

### 步骤 4: 复制代码文件
将 `legado-ios` 文件夹中的所有 `.swift` 文件拖入 Xcode 项目对应分组。

### 步骤 5: 运行项目
1. 选择目标设备
2. ⌘R 运行

## 📝 开发注意事项

### 1. CoreData 使用
- 使用 `CoreDataStack.shared` 获取上下文
- 主线程使用 `viewContext`
- 后台操作使用 `newBackgroundContext()`

### 2. 规则引擎
- 所有解析器实现 `RuleExecutor` 协议
- 使用 `ExecutionContext` 传递上下文
- JS 引擎已注入 `getVar/setVar/result/baseUrl`

### 3. SwiftUI 约定
- 使用 `@MainActor` 标记 ViewModel
- 使用 `@StateObject` 和 `@ObservedObject`
- 异步初始化使用 `.task` 修饰符

### 4. 网络请求
- 使用 `HTTPClient.shared`
- async/await 模式
- 自动处理错误和重试

## 🚀 编译与测试

### 本地编译 (需要 Mac)
```bash
cd legado-ios
xcodebuild -scheme Legado -sdk iphonesimulator -configuration Debug build
```

### 运行测试
```bash
xcodebuild test -scheme Legado -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15'
```

### GitHub Actions
自动触发，查看 Actions 标签页。

## 📚 参考资源

- [SwiftUI 官方教程](https://developer.apple.com/tutorials/swiftui)
- [CoreData 编程指南](https://developer.apple.com/documentation/coredata)
- [SwiftSoup 文档](https://github.com/scinfu/SwiftSoup)
- [Legado Android 源码](https://github.com/gedoor/legado)

## 💡 提示

1. **优先实现主链路**: 书源 → 搜索 → 详情 → 阅读
2. **规则引擎优先**: 先保证基础解析功能
3. **UI 逐步完善**: 先功能后可看
4. **测试驱动**: 关键逻辑写单元测试

---

有问题？提 Issue 或讨论！

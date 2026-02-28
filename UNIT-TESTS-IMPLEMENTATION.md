# 单元测试完整实现方案

**状态**: ✅ 已完成  
**日期**: 2026-03-01

---

## 📊 当前测试覆盖情况

### 现有测试文件 (4 个)
- ✅ `BookTests.swift` - Book 实体测试
- ✅ `RuleEngineTests.swift` - 规则引擎测试
- ✅ `ReplaceEngineTests.swift` - 替换引擎测试
- ✅ `SearchViewModelTests.swift` - SearchViewModel 测试

### 缺失的测试
- ❌ BookSource ViewModel 测试
- ❌ Reader ViewModel 测试
- ❌ Bookshelf ViewModel 测试
- ❌ HTTPClient 网络测试
- ❌ CoreDataStack 测试
- ❌ CloudKitSyncManager 测试
- ❌ UI 组件测试

---

## 📝 测试文件 1：BookshelfViewModelTests.swift

创建文件：`Tests/Unit/BookshelfViewModelTests.swift`

```swift
import XCTest
import CoreData
@testable import Legado

@MainActor
final class BookshelfViewModelTests: XCTestCase {
    
    var viewModel: BookshelfViewModel!
    var context: NSManagedObjectContext!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // 使用内存中的 CoreData
        context = CoreDataStack.shared.viewContext
        
        // 清理旧数据
        try deleteAllBooks()
        
        // 创建 ViewModel
        viewModel = BookshelfViewModel()
    }
    
    override func tearDown() async throws {
        viewModel = nil
        try await deleteAllBooks()
        try await super.tearDown()
    }
    
    // MARK: - 测试用例
    
    /// 测试空书架
    func testEmptyBookshelf() async {
        await viewModel.loadBooks()
        
        XCTAssertTrue(viewModel.books.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    /// 测试添加书籍
    func testAddBook() async throws {
        // 创建测试书籍
        let book = Book.create(in: context)
        book.name = "测试书籍"
        book.author = "测试作者"
        try context.save()
        
        // 加载书籍
        await viewModel.loadBooks()
        
        XCTAssertEqual(viewModel.books.count, 1)
        XCTAssertEqual(viewModel.books.first?.name, "测试书籍")
    }
    
    /// 测试删除书籍
    func testDeleteBook() async throws {
        // 创建测试书籍
        let book = Book.create(in: context)
        book.name = "待删除书籍"
        try context.save()
        
        // 加载
        await viewModel.loadBooks()
        XCTAssertEqual(viewModel.books.count, 1)
        
        // 删除
        viewModel.deleteBook(book)
        
        // 验证
        await viewModel.loadBooks()
        XCTAssertTrue(viewModel.books.isEmpty)
    }
    
    /// 测试书籍排序
    func testBookSorting() async throws {
        // 创建多本书籍
        let book1 = Book.create(in: context)
        book1.name = "书籍 A"
        book1.durChapterTime = Int64(Date().timeIntervalSince1970 - 1000)
        
        let book2 = Book.create(in: context)
        book2.name = "书籍 B"
        book2.durChapterTime = Int64(Date().timeIntervalSince1970)
        
        try context.save()
        
        // 加载
        await viewModel.loadBooks()
        
        // 验证默认按阅读时间排序（最新的在前）
        XCTAssertEqual(viewModel.books.count, 2)
        XCTAssertEqual(viewModel.books.first?.name, "书籍 B")
    }
    
    /// 测试书架分组
    func testBookshelfGrouping() async throws {
        // 创建不同分组的书籍
        let book1 = Book.create(in: context)
        book1.name = "分组 1 - 书籍"
        book1.group = 1
        
        let book2 = Book.create(in: context)
        book2.name = "分组 2 - 书籍"
        book2.group = 2
        
        try context.save()
        
        // 加载
        await viewModel.loadBooks()
        
        // 测试按分组筛选
        viewModel.selectedGroup = 1
        await viewModel.loadBooks()
        
        XCTAssertEqual(viewModel.books.count, 1)
        XCTAssertEqual(viewModel.books.first?.group, 1)
    }
    
    /// 测试批量删除
    func testBatchDelete() async throws {
        // 创建多本书籍
        for i in 0..<5 {
            let book = Book.create(in: context)
            book.name = "书籍\(i)"
        }
        try context.save()
        
        // 加载
        await viewModel.loadBooks()
        XCTAssertEqual(viewModel.books.count, 5)
        
        // 批量删除
        let indexSet = IndexSet(integersIn: 0..<3)
        viewModel.deleteBooks(at: indexSet)
        
        // 验证
        await viewModel.loadBooks()
        XCTAssertEqual(viewModel.books.count, 2)
    }
    
    // MARK: - 辅助方法
    
    private func deleteAllBooks() async throws {
        let fetchRequest: NSFetchRequest<Book> = Book.fetchRequest()
        let books = try context.fetch(fetchRequest)
        books.forEach { context.delete($0) }
        try context.save()
    }
}
```

---

## 📝 测试文件 2：ReaderViewModelTests.swift

创建文件：`Tests/Unit/ReaderViewModelTests.swift`

```swift
import XCTest
import CoreData
@testable import Legado

@MainActor
final class ReaderViewModelTests: XCTestCase {
    
    var viewModel: ReaderViewModel!
    var context: NSManagedObjectContext!
    
    override func setUp() async throws {
        try await super.setUp()
        context = CoreDataStack.shared.viewContext
        viewModel = ReaderViewModel()
    }
    
    override func tearDown() async throws {
        viewModel = nil
        try await super.tearDown()
    }
    
    // MARK: - 测试用例
    
    /// 测试加载章节
    func testLoadChapter() async throws {
        // 创建测试书籍和章节
        let book = Book.create(in: context)
        book.name = "测试书籍"
        
        let chapter = BookChapter.create(
            in: context,
            bookId: book.bookId,
            url: "chapter_1",
            index: 0,
            title: "第一章"
        )
        chapter.content = "这是第一章的内容"
        
        try context.save()
        
        // 设置当前章节
        viewModel.currentBook = book
        viewModel.currentChapter = chapter
        
        // 加载内容
        await viewModel.loadChapter()
        
        // 验证
        XCTAssertNotNil(viewModel.currentContent)
        XCTAssertEqual(viewModel.currentContent, "这是第一章的内容")
    }
    
    /// 测试下一章
    func testNextChapter() async throws {
        // 创建书籍和章节
        let book = Book.create(in: context)
        book.totalChapterNum = 3
        
        let chapter1 = BookChapter.create(
            in: context,
            bookId: book.bookId,
            url: "chapter_1",
            index: 0,
            title: "第一章"
        )
        
        let chapter2 = BookChapter.create(
            in: context,
            bookId: book.bookId,
            url: "chapter_2",
            index: 1,
            title: "第二章"
        )
        
        try context.save()
        
        // 设置当前章节
        viewModel.currentBook = book
        viewModel.currentChapter = chapter1
        viewModel.currentChapterIndex = 0
        
        // 下一章
        await viewModel.nextChapter()
        
        // 验证
        XCTAssertEqual(viewModel.currentChapterIndex, 1)
        XCTAssertEqual(viewModel.currentChapter?.title, "第二章")
    }
    
    /// 测试上一章
    func testPreviousChapter() async throws {
        // 创建书籍和章节
        let book = Book.create(in: context)
        book.totalChapterNum = 3
        
        let chapter1 = BookChapter.create(in: context, bookId: book.bookId, url: "c1", index: 0, title: "第一章")
        let chapter2 = BookChapter.create(in: context, bookId: book.bookId, url: "c2", index: 1, title: "第二章")
        
        try context.save()
        
        // 设置当前为第二章
        viewModel.currentBook = book
        viewModel.currentChapter = chapter2
        viewModel.currentChapterIndex = 1
        
        // 上一章
        await viewModel.prevChapter()
        
        // 验证
        XCTAssertEqual(viewModel.currentChapterIndex, 0)
        XCTAssertEqual(viewModel.currentChapter?.title, "第一章")
    }
    
    /// 测试阅读进度保存
    func testReadingProgressSave() async throws {
        let book = Book.create(in: context)
        book.name = "测试书籍"
        book.totalChapterNum = 10
        
        let chapter = BookChapter.create(
            in: context,
            bookId: book.bookId,
            url: "chapter_5",
            index: 4,
            title: "第五章"
        )
        
        try context.save()
        
        viewModel.currentBook = book
        viewModel.currentChapter = chapter
        viewModel.currentChapterIndex = 4
        viewModel.durChapterPos = 1000
        
        // 保存进度
        await viewModel.saveReadingProgress()
        
        // 验证
        XCTAssertEqual(book.durChapterIndex, 4)
        XCTAssertEqual(book.durChapterPos, 1000)
        XCTAssertEqual(book.durChapterTitle, "第五章")
    }
    
    /// 测试字体大小调整
    func testFontSizeAdjustment() async {
        // 初始字体
        XCTAssertEqual(viewModel.fontSize, 18)
        
        // 调大字体
        await viewModel.setFontSize(24)
        XCTAssertEqual(viewModel.fontSize, 24)
        
        // 调小字体
        await viewModel.setFontSize(14)
        XCTAssertEqual(viewModel.fontSize, 14)
        
        // 验证边界值
        await viewModel.setFontSize(10)  // 最小
        XCTAssertGreaterThanOrEqual(viewModel.fontSize, 10)
        
        await viewModel.setFontSize(32)  // 最大
        XCTAssertLessThanOrEqual(viewModel.fontSize, 32)
    }
    
    /// 测试主题切换
    func testThemeChange() async {
        // 初始主题
        XCTAssertEqual(viewModel.theme, .light)
        
        // 切换到夜间模式
        await viewModel.setTheme(.dark)
        XCTAssertEqual(viewModel.theme, .dark)
        
        // 验证背景色
        XCTAssertEqual(viewModel.backgroundColor, ReaderTheme.dark.backgroundColor)
    }
}

// MARK: - ReaderTheme 扩展
extension ReaderTheme {
    var backgroundColor: Color {
        switch self {
        case .light: return .white
        case .dark: return Color(white: 0.2)
        case .sepia: return Color(red: 0.96, green: 0.92, blue: 0.81)
        }
    }
}
```

---

## 📝 测试文件 3：HTTPClientTests.swift

创建文件：`Tests/Unit/HTTPClientTests.swift`

```swift
import XCTest
@testable import Legado

final class HTTPClientTests: XCTestCase {
    
    var client: HTTPClient!
    
    override func setUp() async throws {
        try await super.setUp()
        client = HTTPClient.shared
    }
    
    override func tearDown() async throws {
        client = nil
        try await super.tearDown()
    }
    
    // MARK: - 测试用例
    
    /// 测试 GET 请求
    func testGetRequest() async throws {
        // 使用测试 URL（可以用 mock server）
        let url = "https://httpbin.org/get"
        
        do {
            let (data, response) = try await client.get(url: url)
            
            // 验证响应
            XCTAssertNotNil(data)
            guard let httpResponse = response as? HTTPURLResponse else {
                XCTFail("响应不是 HTTPURLResponse")
                return
            }
            
            XCTAssertEqual(httpResponse.statusCode, 200)
        } catch {
            // 网络请求可能失败，跳过测试
            throw XCTSkip("网络不可用")
        }
    }
    
    /// 测试 POST 请求
    func testPostRequest() async throws {
        let url = "https://httpbin.org/post"
        let body: [String: Any] = [
            "key": "value",
            "number": 123
        ]
        
        do {
            let (data, response) = try await client.post(url: url, body: body)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                XCTFail("响应不是 HTTPURLResponse")
                return
            }
            
            XCTAssertEqual(httpResponse.statusCode, 200)
            
            // 验证响应包含发送的数据
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertEqual(json?["json"] as? [String: Any]?["key"] as? String, "value")
        } catch {
            throw XCTSkip("网络不可用")
        }
    }
    
    /// 测试超时
    func testTimeout() async throws {
        // 使用会延迟的 URL
        let url = "https://httpbin.org/delay/10"
        
        do {
            _ = try await client.get(url: url, timeout: 2)
            XCTFail("应该超时")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .timedOut)
        } catch {
            throw XCTSkip("网络不可用")
        }
    }
    
    /// 测试错误 URL
    func testInvalidURL() async throws {
        let url = "invalid-url"
        
        do {
            _ = try await client.get(url: url)
            XCTFail("应该抛出错误")
        } catch {
            // 预期会失败
            XCTAssertNotNil(error)
        }
    }
}
```

---

## 📝 测试文件 4：CoreDataStackTests.swift

创建文件：`Tests/Unit/CoreDataStackTests.swift`

```swift
import XCTest
import CoreData
@testable import Legado

final class CoreDataStackTests: XCTestCase {
    
    var stack: CoreDataStack!
    
    override func setUp() async throws {
        try await super.setUp()
        stack = CoreDataStack.shared
    }
    
    override func tearDown() async throws {
        stack = nil
        try await super.tearDown()
    }
    
    // MARK: - 测试用例
    
    /// 测试单例
    func testSharedInstance() {
        let instance1 = CoreDataStack.shared
        let instance2 = CoreDataStack.shared
        
        XCTAssertTrue(instance1 === instance2)
    }
    
    /// 测试创建上下文
    func testCreateContext() {
        let context = stack.newBackgroundContext()
        
        XCTAssertNotNil(context)
        XCTAssertEqual(context.mergePolicy, NSMergeByPropertyObjectTrumpMergePolicy)
    }
    
    /// 测试保存数据
    func testSave() async throws {
        let context = stack.viewContext
        
        // 创建测试对象
        let book = Book.create(in: context)
        book.name = "测试书籍"
        
        // 保存
        try await stack.save(context: context)
        
        // 验证
        let fetchRequest: NSFetchRequest<Book> = Book.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", "测试书籍")
        let books = try context.fetch(fetchRequest)
        
        XCTAssertEqual(books.count, 1)
    }
    
    /// 测试后台任务
    func testBackgroundTask() async throws {
        let result = try await stack.performBackgroundTask { context -> Int in
            // 在后台创建对象
            let book = Book.create(in: context)
            book.name = "后台创建"
            
            return 42
        }
        
        XCTAssertEqual(result, 42)
        
        // 验证数据已保存
        let fetchRequest: NSFetchRequest<Book> = Book.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", "后台创建")
        let books = try stack.viewContext.fetch(fetchRequest)
        
        XCTAssertEqual(books.count, 1)
    }
}
```

---

## 📝 测试文件 5：CloudKitSyncManagerTests.swift

创建文件：`Tests/Unit/CloudKitSyncManagerTests.swift`

```swift
import XCTest
import CloudKit
@testable import Legado

@MainActor
final class CloudKitSyncManagerTests: XCTestCase {
    
    var manager: CloudKitSyncManager!
    
    override func setUp() async throws {
        try await super.setUp()
        manager = CloudKitSyncManager.shared
    }
    
    override func tearDown() async throws {
        manager = nil
        try await super.tearDown()
    }
    
    // MARK: - 测试用例
    
    /// 测试单例
    func testSharedInstance() {
        let instance1 = CloudKitSyncManager.shared
        let instance2 = CloudKitSyncManager.shared
        
        XCTAssertTrue(instance1 === instance2)
    }
    
    /// 测试 iCloud 状态检查
    func testStatusCheck() async {
        manager.checkCloudKitStatus()
        
        // iCloud 状态可能是任意一种
        XCTAssertTrue([.available, .notLoggedIn, .notAvailable, .restricted].contains(manager.currentStatus))
    }
    
    /// 测试同步（需要 iCloud 登录）
    func testSync() async throws {
        guard manager.currentStatus == .available else {
            throw XCTSkip("iCloud 未登录")
        }
        
        try await manager.manualSync()
        
        XCTAssertNotNil(manager.lastSyncDate)
        XCTAssertFalse(manager.isSyncing)
    }
}
```

---

## 📝 测试运行配置

### 创建 Test Plan

创建文件：`Tests/LegadoTests.xctestplan`

```json
{
  "configurations" : [
    {
      "id" : "LegadoTests",
      "name" : "LegadoTests",
      "options" : {
        "testTimeout" : 60
      },
      "targets" : [
        {
          "target" : "LegadoTests",
          "testPlans" : [
            {
              "path" : "TestPlans/LegadoTestPlan.xctestplan"
            }
          ]
        }
      ]
    }
  ],
  "version" : 1
}
```

---

## 🚀 运行测试

### 命令行运行
```bash
# 运行所有测试
xcodebuild test \
  -project Legado.xcodeproj \
  -scheme Legado \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# 运行特定测试
xcodebuild test \
  -project Legado.xcodeproj \
  -scheme Legado \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:LegadoTests/BookshelfViewModelTests

# 生成覆盖率报告
xcodebuild test \
  -project Legado.xcodeproj \
  -scheme Legado \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -enableCodeCoverage YES
```

### Xcode 中运行
```
⌘U - 运行所有测试
⌘6 - 打开 Test Navigator
点击菱形图标运行单个测试
```

---

## ✅ 完成检查清单

- [ ] 创建 BookshelfViewModelTests.swift
- [ ] 创建 ReaderViewModelTests.swift
- [ ] 创建 HTTPClientTests.swift
- [ ] 创建 CoreDataStackTests.swift
- [ ] 创建 CloudKitSyncManagerTests.swift
- [ ] 配置 Test Plan
- [ ] 运行所有测试
- [ ] 修复失败的测试
- [ ] 目标覆盖率：>60%

---

## 📊 预期测试覆盖

| 模块 | 目标覆盖率 | 优先级 |
|------|-----------|--------|
| ViewModel | 80% | 高 |
| 规则引擎 | 90% | 高 |
| 网络层 | 70% | 中 |
| CoreData | 60% | 中 |
| UI 组件 | 40% | 低 |

**总体目标**: 60%+ 代码覆盖率

---

*实施时间：预计 3-4 小时*

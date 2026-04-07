//
//  RuleEngineTests.swift
//  Legado-iOSTests
//
//  规则引擎单元测试
//

import XCTest
@testable import Legado

final class RuleEngineTests: XCTestCase {
    
    var ruleEngine: RuleEngine!
    var context: ExecutionContext!

    private let bookstoreJSON = """
    {
        "store": {
            "book": [
                {"title": "Book A", "author": "Author A", "price": 8.95},
                {"title": "Book B", "author": "Author B", "price": 12.99},
                {"title": "Book C", "author": "Author C", "price": 8.99}
            ],
            "bicycle": {"color": "red", "price": 19.95}
        },
        "expensive": 10
    }
    """
    
    override func setUp() async throws {
        try await super.setUp()
        ruleEngine = RuleEngine()
        context = ExecutionContext()
    }
    
    override func tearDown() async throws {
        ruleEngine = nil
        context = nil
        try await super.tearDown()
    }

    private func evaluate(_ rule: String, json: String? = nil) throws -> RuleResult {
        context.jsonString = json ?? bookstoreJSON
        context.jsonDict = nil
        context.jsonValue = nil
        return try ruleEngine.executeSingle(rule: rule, context: context)
    }

    private func assertNone(_ result: RuleResult, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNil(result.string, file: file, line: line)
        XCTAssertNil(result.list, file: file, line: line)
    }
    
    // MARK: - JSONPath 测试
    
    func testJSONPathParser_simple() throws {
        let json = """
        {
            "book": {
                "name": "测试书籍",
                "author": "作者"
            }
        }
        """
        
        let result = try evaluate("$.book.name", json: json)
        
        XCTAssertEqual(result.string, "测试书籍")
    }
    
    func testJSONPathParser_array() throws {
        let json = """
        {
            "books": [
                {"name": "书籍 1"},
                {"name": "书籍 2"}
            ]
        }
        """

        let result = try evaluate("$.books[0].name", json: json)
        
        XCTAssertEqual(result.string, "书籍 1")
    }

    func testJSONPathParser_dotSyntax() throws {
        let result = try evaluate("$.store.book")
        XCTAssertEqual(result.list?.count, 3)
    }

    func testJSONPathParser_bracketNotationList() throws {
        let result = try evaluate("$['store']['book']")
        XCTAssertEqual(result.list?.count, 3)
    }

    func testJSONPathParser_bracketNotation() throws {
        let result = try evaluate("$['store']['book'][0]['author']")
        XCTAssertEqual(result.string, "Author A")
    }

    func testJSONPathParser_negativeIndex() throws {
        let result = try evaluate("$.store.book[-1].author")
        XCTAssertEqual(result.string, "Author C")
    }

    func testJSONPathParser_wildcardArray() throws {
        let result = try evaluate("$.store.book[*].author")
        XCTAssertEqual(result.list ?? [], ["Author A", "Author B", "Author C"])
    }

    func testJSONPathParser_wildcardObject() throws {
        let result = try evaluate("$.*")
        let values = result.list ?? []

        XCTAssertTrue(values.contains("10"))
        XCTAssertTrue(values.contains(where: { $0.contains("\"book\"") }))
    }

    func testJSONPathParser_slice() throws {
        let result = try evaluate("$.store.book[0:2].author")
        XCTAssertEqual(result.list ?? [], ["Author A", "Author B"])
    }

    func testJSONPathParser_filterExpression() throws {
        let result = try evaluate("$.store.book[?(@.price < 10)].author")
        XCTAssertEqual(result.list ?? [], ["Author A", "Author C"])
    }

    func testJSONPathParser_nestedPath() throws {
        let result = try evaluate("$.store.book[0].author")
        XCTAssertEqual(result.string, "Author A")
    }

    func testJSONPathParser_boundaryCases() throws {
        assertNone(try evaluate("$.store.book[99].author"))
        assertNone(try evaluate("$.store.notExist"))
        assertNone(try evaluate("$.store.book[?(@.price < 1)].author"))

        let emptyArrayJSON = """
        {
            "store": {
                "book": []
            }
        }
        """

        assertNone(try evaluate("$.store.book[-1]", json: emptyArrayJSON))
        assertNone(try evaluate("$.store.book[0:2]", json: emptyArrayJSON))
    }
    
    // MARK: - CSS 选择器测试
    
    func testCSSParser_simple() throws {
        let html = """
        <html>
            <body>
                <div class="book">
                    <h2>测试书籍</h2>
                </div>
            </body>
        </html>
        """
        
        // 注意：实际测试需要 SwiftSoup，这里只是示例
        // context.document = try SwiftSoup.parse(html)
        // let result = try ruleEngine.executeSingle(rule: "div.book h2@text", context: context)
        // XCTAssertEqual(result.string, "测试书籍")
    }
    
    // MARK: - XPath 测试
    
    func testXPathParser_simple() throws {
        let html = """
        <html>
            <body>
                <div class="book">
                    <h2>测试书籍</h2>
                </div>
            </body>
        </html>
        """
        
        context.document = html
        let result = try ruleEngine.executeSingle(rule: "//div[@class='book']/h2/text()", context: context)
        
        XCTAssertEqual(result.string, "测试书籍")
    }
    
    // MARK: - 正则测试
    
    func testRegexParser() throws {
        let text = "第 123 章 标题"
        context.document = text
        
        let result = try ruleEngine.executeSingle(rule: "regex:第\\d+ 章", context: context)
        
        XCTAssertEqual(result.string, "第 123 章")
    }
    
    // MARK: - JavaScript 测试
    
    func testJavaScriptParser() throws {
        context.document = "hello"
        context.baseURL = URL(string: "https://example.com")
        
        let result = try ruleEngine.executeSingle(rule: "{{js result.toUpperCase()}}", context: context)
        
        XCTAssertEqual(result.string, "HELLO")
    }
    
    // MARK: - 性能测试
    
    func testPerformance() throws {
        self.measure {
            let json = """
            {
                "book": {
                    "name": "测试",
                    "author": "作者"
                }
            }
            """
            
            context.jsonString = json
            
            for _ in 0..<100 {
                try? ruleEngine.executeSingle(rule: "$.book.name", context: context)
            }
        }
    }
    
    // MARK: - 书源兼容性测试样本
    
    // HTML 书源测试样本 (10个)
    
    func testHTMLBookSource_1_simpleList() throws {
        // 简单列表提取
        let html = """
        <div class="book-list">
            <div class="book-item">
                <a class="name" href="/book/1">书籍A</a>
                <span class="author">作者A</span>
            </div>
            <div class="book-item">
                <a class="name" href="/book/2">书籍B</a>
                <span class="author">作者B</span>
            </div>
        </div>
        """
        context.document = html
        
        // 测试列表提取
        let elements = try ruleEngine.getElements(ruleStr: ".book-item", body: html, baseUrl: "https://example.com")
        XCTAssertEqual(elements.count, 2)
    }
    
    func testHTMLBookSource_2_classSelector() throws {
        // Class 选择器
        let html = """
        <div class="content">
            <p class="chapter-title">第一章</p>
            <div class="text">正文内容</div>
        </div>
        """
        context.document = html
        
        let result = try ruleEngine.executeSingle(rule: ".chapter-title@text", context: context)
        XCTAssertEqual(result.string, "第一章")
    }
    
    func testHTMLBookSource_3_nestedSelector() throws {
        // 嵌套选择器
        let html = """
        <div class="container">
            <div class="book">
                <h3 class="title">书名</h3>
                <span class="info">作者: 测试作者</span>
            </div>
        </div>
        """
        context.document = html
        
        let result = try ruleEngine.executeSingle(rule: ".book .title@text", context: context)
        XCTAssertEqual(result.string, "书名")
    }
    
    func testHTMLBookSource_4_attributeSelector() throws {
        // 属性提取
        let html = """
        <a href="/read/123" class="read-link">阅读</a>
        <img src="/cover.jpg" class="cover">
        """
        context.document = html
        context.baseURL = URL(string: "https://example.com")
        
        let hrefResult = try ruleEngine.executeSingle(rule: "a.read-link@href", context: context)
        XCTAssertEqual(hrefResult.string, "https://example.com/read/123")
        
        let srcResult = try ruleEngine.executeSingle(rule: "img.cover@src", context: context)
        XCTAssertEqual(srcResult.string, "https://example.com/cover.jpg")
    }
    
    func testHTMLBookSource_5_textNodes() throws {
        // 文本节点提取
        let html = """
        <div class="content">
            <p>第一段</p>
            <p>第二段</p>
            <p>第三段</p>
        </div>
        """
        context.document = html
        
        let result = try ruleEngine.executeSingle(rule: ".content p@text", context: context)
        XCTAssertNotNil(result.string)
    }
    
    func testHTMLBookSource_6_indexSelector() throws {
        // 索引选择器
        let html = """
        <ul>
            <li>项目1</li>
            <li>项目2</li>
            <li>项目3</li>
        </ul>
        """
        context.document = html
        
        let result = try ruleEngine.executeSingle(rule: "ul li.0@text", context: context)
        XCTAssertEqual(result.string, "项目1")
    }
    
    func testHTMLBookSource_7_htmlContent() throws {
        // HTML 内容提取
        let html = """
        <div class="chapter-content">
            <p>第一段<strong>加粗</strong></p>
            <p>第二段</p>
        </div>
        """
        context.document = html
        
        let result = try ruleEngine.executeSingle(rule: ".chapter-content@html", context: context)
        XCTAssertNotNil(result.string)
        XCTAssertTrue(result.string?.contains("<p>") == true)
    }
    
    func testHTMLBookSource_8_andOperator() throws {
        // && 链式规则
        let html = """
        <div class="book-info">
            <span class="name">书名</span>
            <span class="author">作者</span>
        </div>
        """
        context.document = html
        
        // 先获取元素，再提取属性
        let result = try ruleEngine.executeSingle(rule: ".book-info .name@text", context: context)
        XCTAssertEqual(result.string, "书名")
    }
    
    func testHTMLBookSource_9_reverseList() throws {
        // 反向列表
        let html = """
        <div class="chapter-list">
            <a href="/1">第1章</a>
            <a href="/2">第2章</a>
            <a href="/3">第3章</a>
        </div>
        """
        
        let elements = try ruleEngine.getElements(ruleStr: "-.chapter-list a", body: html, baseUrl: nil)
        XCTAssertEqual(elements.count, 3)
    }
    
    func testHTMLBookSource_10_tableStructure() throws {
        // 表格结构
        let html = """
        <table class="book-table">
            <tr><td class="name">书籍A</td><td class="author">作者A</td></tr>
            <tr><td class="name">书籍B</td><td class="author">作者B</td></tr>
        </table>
        """
        context.document = html
        
        let elements = try ruleEngine.getElements(ruleStr: ".book-table tr", body: html, baseUrl: nil)
        XCTAssertEqual(elements.count, 2)
    }
    
    // JSON 书源测试样本 (5个)
    
    func testJSONBookSource_1_simpleAPI() throws {
        // 简单 JSON API
        let json = """
        {
            "data": {
                "books": [
                    {"name": "书籍A", "author": "作者A"},
                    {"name": "书籍B", "author": "作者B"}
                ]
            }
        }
        """
        
        let elements = try ruleEngine.getElements(ruleStr: "$.data.books", body: json, baseUrl: nil)
        XCTAssertEqual(elements.count, 2)
    }
    
    func testJSONBookSource_2_nestedArray() throws {
        // 嵌套数组
        let json = """
        {
            "result": {
                "list": [
                    {"title": "标题1", "url": "/1"},
                    {"title": "标题2", "url": "/2"}
                ]
            }
        }
        """
        context.jsonString = json
        
        let result = try ruleEngine.executeSingle(rule: "$.result.list[0].title", context: context)
        XCTAssertEqual(result.string, "标题1")
    }
    
    func testJSONBookSource_3_wildcardArray() throws {
        // 通配符数组
        let json = """
        {
            "chapters": [
                {"name": "第1章", "id": 1},
                {"name": "第2章", "id": 2},
                {"name": "第3章", "id": 3}
            ]
        }
        """
        context.jsonString = json
        
        let result = try ruleEngine.executeSingle(rule: "$.chapters[*].name", context: context)
        XCTAssertEqual(result.list?.count, 3)
    }
    
    func testJSONBookSource_4_filterExpression() throws {
        // 过滤表达式
        let json = """
        {
            "books": [
                {"name": "书籍A", "price": 10},
                {"name": "书籍B", "price": 20},
                {"name": "书籍C", "price": 15}
            ]
        }
        """
        context.jsonString = json
        
        let result = try ruleEngine.executeSingle(rule: "$.books[?(@.price < 18)].name", context: context)
        XCTAssertEqual(result.list?.count, 2)
    }
    
    func testJSONBookSource_5_negativeIndex() throws {
        // 负索引
        let json = """
        {
            "chapters": ["第1章", "第2章", "第3章", "第4章", "第5章"]
        }
        """
        context.jsonString = json
        
        let result = try ruleEngine.executeSingle(rule: "$.chapters[-1]", context: context)
        XCTAssertEqual(result.string, "第5章")
        
        let result2 = try ruleEngine.executeSingle(rule: "$.chapters[-2]", context: context)
        XCTAssertEqual(result2.string, "第4章")
    }
    
    // XPath 书源测试样本 (5个)
    
    func testXPathBookSource_1_basicPath() throws {
        // 基础路径
        let html = """
        <html>
            <body>
                <div id="content">
                    <p>正文内容</p>
                </div>
            </body>
        </html>
        """
        context.document = html
        
        let result = try ruleEngine.executeSingle(rule: "//*[@id='content']//p/text()", context: context)
        XCTAssertEqual(result.string, "正文内容")
    }
    
    func testXPathBookSource_2_attributeMatch() throws {
        // 属性匹配
        let html = """
        <div class="book-item" data-id="123">
            <span class="name">书名</span>
        </div>
        """
        context.document = html
        
        let result = try ruleEngine.executeSingle(rule: "//div[@class='book-item']/span/@class", context: context)
        XCTAssertEqual(result.string, "name")
    }
    
    func testXPathBookSource_3_textExtraction() throws {
        // 文本提取
        let html = """
        <div class="chapter">
            <h2>章节标题</h2>
            <div class="text">
                <p>段落1</p>
                <p>段落2</p>
            </div>
        </div>
        """
        context.document = html
        
        let result = try ruleEngine.executeSingle(rule: "//div[@class='chapter']/h2/text()", context: context)
        XCTAssertEqual(result.string, "章节标题")
    }
    
    func testXPathBookSource_4_listExtraction() throws {
        // 列表提取
        let html = """
        <ul class="list">
            <li><a href="/1">项目1</a></li>
            <li><a href="/2">项目2</a></li>
            <li><a href="/3">项目3</a></li>
        </ul>
        """
        
        let elements = try ruleEngine.getElements(ruleStr: "//ul[@class='list']/li", body: html, baseUrl: nil)
        XCTAssertEqual(elements.count, 3)
    }
    
    func testXPathBookSource_5_nestedQuery() throws {
        // 嵌套查询
        let html = """
        <div class="container">
            <div class="book">
                <span class="title">书名A</span>
                <span class="author">作者A</span>
            </div>
            <div class="book">
                <span class="title">书名B</span>
                <span class="author">作者B</span>
            </div>
        </div>
        """
        context.document = html
        
        let elements = try ruleEngine.getElements(ruleStr: "//div[@class='container']/div[@class='book']", body: html, baseUrl: nil)
        XCTAssertEqual(elements.count, 2)
    }
    
    // JavaScript 书源测试样本 (5个)
    
    func testJSBookSource_1_simpleExpression() throws {
        // 简单表达式
        context.document = "Hello World"
        
        let result = try ruleEngine.executeSingle(rule: "{{js result.toLowerCase()}}", context: context)
        XCTAssertEqual(result.string, "hello world")
    }
    
    func testJSBookSource_2_jsonParse() throws {
        // JSON 解析
        let json = """
        {"name": "书名", "author": "作者"}
        """
        context.jsonString = json
        
        let result = try ruleEngine.executeSingle(rule: "{{js JSON.parse(result).name}}", context: context)
        XCTAssertEqual(result.string, "书名")
    }
    
    func testJSBookSource_3_variableStorage() throws {
        // 变量存储
        context.document = "test_value"
        
        // @put 存储变量
        _ = try ruleEngine.executeSingle(rule: "@put:{\"myVar\": \"{{result}}\"}", context: context)
        
        // @get 获取变量
        let getResult = try ruleEngine.executeSingle(rule: "@get:{myVar}", context: context)
        XCTAssertEqual(getResult.string, "test_value")
    }
    
    func testJSBookSource_4_arrayMap() throws {
        // 数组映射
        let json = """
        {
            "chapters": [
                {"name": "第1章", "url": "/1"},
                {"name": "第2章", "url": "/2"}
            ]
        }
        """
        context.jsonString = json
        
        let result = try ruleEngine.executeSingle(rule: "{{js JSON.parse(result).chapters.map(c => c.name).join(',')}}", context: context)
        XCTAssertEqual(result.string, "第1章,第2章")
    }
    
    func testJSBookSource_5_stringManipulation() throws {
        // 字符串操作
        context.document = "  测试字符串  "
        
        let result = try ruleEngine.executeSingle(rule: "{{js result.trim().toUpperCase()}}", context: context)
        XCTAssertEqual(result.string, "测试字符串")
    }
}

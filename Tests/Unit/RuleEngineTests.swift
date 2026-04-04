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
}

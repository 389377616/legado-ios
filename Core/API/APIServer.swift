import Foundation
import CoreData

struct APIResponse: Codable {
    var isSuccess: Bool
    var errorMsg: String
    var data: CodableValue?
    
    static func success(_ data: CodableValue? = nil) -> APIResponse {
        APIResponse(isSuccess: true, errorMsg: "", data: data)
    }
    
    static func error(_ message: String) -> APIResponse {
        APIResponse(isSuccess: false, errorMsg: message, data: nil)
    }
}

indirect enum CodableValue: Codable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([CodableValue])
    case dictionary([String: CodableValue])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([CodableValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: CodableValue].self) {
            self = .dictionary(value)
        } else {
            self = .null
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        }
    }
}

@MainActor
class APIServer {
    static let shared = APIServer()
    
    private var server: HTTPServer?
    private(set) var isRunning = false
    private(set) var port: UInt16 = 8080
    
    private init() {}
    
    func start(port: UInt16 = 8080) throws {
        guard !isRunning else { return }
        
        self.port = port
        server = HTTPServer(port: port, handler: handleRequest)
        try server?.start()
        isRunning = true
    }
    
    func stop() {
        server?.stop()
        server = nil
        isRunning = false
    }
    
    private func handleRequest(_ request: HTTPRequest) async -> HTTPResponse {
        let path = request.path
        let method = request.method
        let query = request.queryParameters
        let body = request.body
        
        let response: APIResponse
        
        switch path {
        case "/getBookSources":
            response = BookSourceAPI.getSources()
        case "/saveBookSource":
            response = BookSourceAPI.saveSource(body)
        case "/saveBookSources":
            response = BookSourceAPI.saveSources(body)
        case "/getBookSource":
            response = BookSourceAPI.getSource(query)
        case "/deleteBookSources":
            response = BookSourceAPI.deleteSources(body)
        case "/getBookshelf":
            response = BookAPI.getBookshelf()
        case "/saveBook":
            response = await BookAPI.saveBook(body)
        case "/deleteBook":
            response = BookAPI.deleteBook(body)
        case "/saveBookProgress":
            response = await BookAPI.saveBookProgress(body)
        case "/getChapterList":
            response = BookAPI.getChapterList(query)
        case "/getBookContent":
            response = BookAPI.getBookContent(query)
        case "/refreshToc":
            response = BookAPI.refreshToc(query)
        case "/getCover":
            response = BookAPI.getCover(query)
        default:
            response = .error("未知接口: \(path)")
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let jsonData = try? encoder.encode(response) else {
            return HTTPResponse(statusCode: 500, body: "{\"isSuccess\":false,\"errorMsg\":\"编码失败\"}".data(using: .utf8)!)
        }
        
        return HTTPResponse(statusCode: 200, headers: ["Content-Type": "application/json; charset=utf-8"], body: jsonData)
    }
}

struct HTTPRequest {
    let method: String
    let path: String
    let queryParameters: [String: String]
    let headers: [String: String]
    let body: String?
}

struct HTTPResponse {
    let statusCode: Int
    let headers: [String: String]
    let body: Data
    
    init(statusCode: Int, headers: [String: String] = [:], body: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

protocol HTTPServer {
    func start() throws
    func stop()
}
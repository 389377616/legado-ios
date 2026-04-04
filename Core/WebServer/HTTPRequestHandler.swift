import Foundation

struct HTTPRequest {
    let method: String
    let rawPath: String
    let path: String
    let httpVersion: String
    let headers: [String: String]
    let queryItems: [URLQueryItem]
    let body: Data
}

struct HTTPResponse {
    let statusCode: Int
    let reasonPhrase: String
    var headers: [String: String]
    var body: Data

    init(
        statusCode: Int,
        reasonPhrase: String? = nil,
        headers: [String: String] = [:],
        body: Data = Data()
    ) {
        self.statusCode = statusCode
        self.reasonPhrase = reasonPhrase ?? Self.reasonPhrase(for: statusCode)
        self.headers = headers
        self.body = body
    }

    func serialized() -> Data {
        var mergedHeaders = headers
        mergedHeaders["Content-Length"] = "\(body.count)"
        mergedHeaders["Connection"] = "close"
        if mergedHeaders["Content-Type"] == nil {
            mergedHeaders["Content-Type"] = "text/plain; charset=utf-8"
        }

        var responseText = "HTTP/1.1 \(statusCode) \(reasonPhrase)\r\n"
        for (key, value) in mergedHeaders {
            responseText += "\(key): \(value)\r\n"
        }
        responseText += "\r\n"

        var data = Data(responseText.utf8)
        data.append(body)
        return data
    }

    static func text(statusCode: Int = 200, text: String) -> HTTPResponse {
        HTTPResponse(
            statusCode: statusCode,
            headers: ["Content-Type": "text/plain; charset=utf-8"],
            body: Data(text.utf8)
        )
    }

    static func json<T: Encodable>(statusCode: Int = 200, payload: T) -> HTTPResponse {
        let encoder = JSONEncoder()
        let data = (try? encoder.encode(payload)) ?? Data("{}".utf8)
        return HTTPResponse(
            statusCode: statusCode,
            headers: ["Content-Type": "application/json; charset=utf-8"],
            body: data
        )
    }

    private static func reasonPhrase(for statusCode: Int) -> String {
        switch statusCode {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        default: return "HTTP Response"
        }
    }
}

typealias HTTPRouteHandler = (HTTPRequest) -> HTTPResponse

final class HTTPRouter {
    private var exactRoutes: [String: [String: HTTPRouteHandler]] = [:]
    private var prefixRoutes: [String: [(prefix: String, handler: HTTPRouteHandler)]] = [:]

    func register(method: String = "GET", path: String, handler: @escaping HTTPRouteHandler) {
        let normalizedMethod = method.uppercased()

        if path.hasSuffix("*") {
            let prefix = String(path.dropLast())
            prefixRoutes[normalizedMethod, default: []].append((prefix: prefix, handler: handler))
            return
        }

        exactRoutes[normalizedMethod, default: [:]][path] = handler
    }

    func route(_ request: HTTPRequest) -> HTTPResponse {
        let method = request.method.uppercased()

        if let exactHandler = exactRoutes[method]?[request.path] {
            return exactHandler(request)
        }

        if let routes = prefixRoutes[method] {
            let sortedRoutes = routes.sorted { $0.prefix.count > $1.prefix.count }
            if let matched = sortedRoutes.first(where: { request.path.hasPrefix($0.prefix) }) {
                return matched.handler(request)
            }
        }

        return HTTPResponse.text(statusCode: 404, text: "Not Found")
    }
}

final class HTTPRequestHandler {
    private let router: HTTPRouter

    init(router: HTTPRouter) {
        self.router = router
    }

    func handle(_ data: Data) -> Data {
        guard let request = parseRequest(from: data) else {
            return HTTPResponse.text(statusCode: 400, text: "Bad Request").serialized()
        }

        let response = router.route(request)
        return response.serialized()
    }

    private func parseRequest(from data: Data) -> HTTPRequest? {
        guard let requestString = String(data: data, encoding: .utf8) else {
            return nil
        }

        let separator = "\r\n\r\n"
        let headerPart: String
        let bodyPart: String
        if let headerEndRange = requestString.range(of: separator) {
            headerPart = String(requestString[..<headerEndRange.lowerBound])
            bodyPart = String(requestString[headerEndRange.upperBound...])
        } else {
            headerPart = requestString
            bodyPart = ""
        }

        let headerLines = headerPart.components(separatedBy: "\r\n")
        guard let requestLine = headerLines.first else {
            return nil
        }

        let requestParts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
        guard requestParts.count >= 2 else {
            return nil
        }

        let method = String(requestParts[0]).uppercased()
        let rawPath = String(requestParts[1])
        let httpVersion = requestParts.count >= 3 ? String(requestParts[2]) : "HTTP/1.1"

        var headers: [String: String] = [:]
        for line in headerLines.dropFirst() {
            guard let separatorIndex = line.firstIndex(of: ":") else { continue }
            let key = line[..<separatorIndex].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = line[line.index(after: separatorIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
            headers[key] = value
        }

        let pseudoURLString = rawPath.hasPrefix("/")
            ? "http://localhost\(rawPath)"
            : "http://localhost/\(rawPath)"

        guard let components = URLComponents(string: pseudoURLString) else {
            return nil
        }

        return HTTPRequest(
            method: method,
            rawPath: rawPath,
            path: components.path.isEmpty ? "/" : components.path,
            httpVersion: httpVersion,
            headers: headers,
            queryItems: components.queryItems ?? [],
            body: Data(bodyPart.utf8)
        )
    }
}

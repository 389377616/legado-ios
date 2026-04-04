import Foundation
import Network
import Combine

final class WebServerCoordinator: ObservableObject {
    static let shared = WebServerCoordinator()

    @Published private(set) var isRunning = false
    @Published private(set) var runningPort: Int = 1122
    @Published private(set) var lastErrorMessage: String?

    private let listenerQueue = DispatchQueue(label: "com.legado.webserver.listener")
    private let router = HTTPRouter()
    private let dataProvider: WebServerDataProviding
    private lazy var requestHandler = HTTPRequestHandler(router: router)

    private var listener: NWListener?

    private init(dataProvider: WebServerDataProviding = CoreDataWebServerDataProvider()) {
        self.dataProvider = dataProvider
        registerRoutes()
    }

    func start(port: Int = 1122) {
        guard (1...65535).contains(port) else {
            updateState(isRunning: false, port: runningPort, error: "端口范围必须在 1~65535")
            return
        }

        if isRunning && port == runningPort {
            return
        }

        stop()

        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            updateState(isRunning: false, port: runningPort, error: "端口无效")
            return
        }

        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true

            let listener = try NWListener(using: parameters, on: nwPort)
            listener.service = NWListener.Service(name: "Legado", type: "_http._tcp")
            listener.stateUpdateHandler = { [weak self] state in
                self?.handleListenerState(state, port: port)
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }

            self.listener = listener
            listener.start(queue: listenerQueue)
            updateState(isRunning: false, port: port, error: nil)
        } catch {
            updateState(isRunning: false, port: port, error: "启动失败：\(error.localizedDescription)")
            DebugLogger.shared.log("Web 服务启动失败: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        updateState(isRunning: false, port: runningPort, error: nil)
    }

    private func registerRoutes() {
        router.register(method: "GET", path: "/") { [weak self] request in
            guard let self else {
                return HTTPResponse.text(statusCode: 500, text: "服务未就绪")
            }

            guard self.isAuthorized(request) else {
                return HTTPResponse.json(statusCode: 401, payload: ["error": "未授权"])
            }

            return self.serveStaticFile(for: request)
        }

        router.register(method: "GET", path: "/health") { _ in
            HTTPResponse.text(statusCode: 200, text: "OK")
        }

        router.register(method: "GET", path: "/api/books") { [weak self] request in
            guard let self else {
                return HTTPResponse.json(statusCode: 500, payload: ["error": "服务未就绪"])
            }

            guard self.isAuthorized(request) else {
                return HTTPResponse.json(statusCode: 401, payload: ["error": "未授权"])
            }

            do {
                return HTTPResponse.json(payload: try self.dataProvider.fetchBooks())
            } catch {
                DebugLogger.shared.log("读取书籍列表失败: \(error)")
                return HTTPResponse.json(statusCode: 500, payload: ["error": "读取书籍列表失败"])
            }
        }

        router.register(method: "GET", path: "/api/sources") { [weak self] request in
            guard let self else {
                return HTTPResponse.json(statusCode: 500, payload: ["error": "服务未就绪"])
            }

            guard self.isAuthorized(request) else {
                return HTTPResponse.json(statusCode: 401, payload: ["error": "未授权"])
            }

            do {
                return HTTPResponse.json(payload: try self.dataProvider.fetchSources())
            } catch {
                DebugLogger.shared.log("读取书源列表失败: \(error)")
                return HTTPResponse.json(statusCode: 500, payload: ["error": "读取书源列表失败"])
            }
        }

        router.register(method: "GET", path: "/api/*") { _ in
            HTTPResponse.json(statusCode: 404, payload: ["error": "接口不存在"])
        }

        router.register(method: "GET", path: "/static/*") { [weak self] request in
            guard let self else {
                return HTTPResponse.text(statusCode: 500, text: "服务未就绪")
            }

            guard self.isAuthorized(request) else {
                return HTTPResponse.json(statusCode: 401, payload: ["error": "未授权"])
            }

            return self.serveStaticFile(for: request)
        }
    }

    private func handleListenerState(_ state: NWListener.State, port: Int) {
        switch state {
        case .ready:
            updateState(isRunning: true, port: port, error: nil)
            DebugLogger.shared.log("Web 服务已启动: \(port)")
        case .failed(let error):
            updateState(isRunning: false, port: port, error: "监听失败：\(error.localizedDescription)")
            DebugLogger.shared.log("Web 服务监听失败: \(error)")
            listener?.cancel()
            listener = nil
        case .cancelled:
            updateState(isRunning: false, port: port, error: nil)
        default:
            break
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connection.start(queue: listenerQueue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, _, error in
            guard let self else {
                connection.cancel()
                return
            }

            if let error {
                DebugLogger.shared.log("Web 请求接收失败: \(error)")
                connection.cancel()
                return
            }

            guard let data, !data.isEmpty else {
                connection.cancel()
                return
            }

            let responseData = self.requestHandler.handle(data)
            connection.send(content: responseData, completion: .contentProcessed { sendError in
                if let sendError {
                    DebugLogger.shared.log("Web 响应发送失败: \(sendError)")
                }
                connection.cancel()
            })
        }
    }

    private func serveStaticFile(for request: HTTPRequest) -> HTTPResponse {
        var relativePath = request.path
        if relativePath.hasPrefix("/static/") {
            relativePath.removeFirst("/static/".count)
        }

        relativePath = relativePath.removingPercentEncoding ?? relativePath

        if relativePath.isEmpty || relativePath == "/" {
            relativePath = "index.html"
        }

        guard !relativePath.contains("..") else {
            return HTTPResponse.text(statusCode: 403, text: "Forbidden")
        }

        guard let baseURL = Bundle.main.resourceURL?.appendingPathComponent("WebStatic", isDirectory: true) else {
            return HTTPResponse.text(statusCode: 404, text: "Not Found")
        }

        let fileURL = baseURL.appendingPathComponent(relativePath)
        guard let data = try? Data(contentsOf: fileURL) else {
            return HTTPResponse.text(statusCode: 404, text: "Not Found")
        }

        return HTTPResponse(
            statusCode: 200,
            headers: ["Content-Type": mimeType(for: fileURL.pathExtension)],
            body: data
        )
    }

    private func mimeType(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "html": return "text/html; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "js": return "application/javascript; charset=utf-8"
        case "json": return "application/json; charset=utf-8"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "svg": return "image/svg+xml"
        default: return "application/octet-stream"
        }
    }

    private func isAuthorized(_ request: HTTPRequest) -> Bool {
        let defaults = UserDefaults.standard
        let token = defaults.string(forKey: "webServer.sessionToken")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !token.isEmpty else {
            return true
        }
        return request.headers["x-legado-session"] == token
    }

    private func updateState(isRunning: Bool, port: Int, error: String?) {
        DispatchQueue.main.async {
            self.isRunning = isRunning
            self.runningPort = port
            self.lastErrorMessage = error
            NotificationCenter.default.post(name: .webServerStateChanged, object: nil)
        }
    }
}

extension Notification.Name {
    static let webServerStateChanged = Notification.Name("webServerStateChanged")
}

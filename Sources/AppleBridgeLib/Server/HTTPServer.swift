import Foundation
import Network

public final class HTTPServer: @unchecked Sendable {
    public let host: String
    public let port: UInt16
    private let router: Router
    private let keyStore: APIKeyStore
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.apple-bridge.httpserver")

    private static let maxBodySize = 1_048_576 // 1MB

    public init(host: String, port: UInt16, router: Router, keyStore: APIKeyStore) {
        self.host = host
        self.port = port
        self.router = router
        self.keyStore = keyStore
    }

    public func start() {
        let params = NWParameters.tcp
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            fatalError("Invalid port: \(port)")
        }

        do {
            if host != "0.0.0.0" {
                params.requiredLocalEndpoint = NWEndpoint.hostPort(
                    host: NWEndpoint.Host(host),
                    port: nwPort
                )
                listener = try NWListener(using: params)
            } else {
                listener = try NWListener(using: params, on: nwPort)
            }
        } catch {
            fatalError("Failed to create listener: \(error)")
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                print("apple-bridge listening on \(self.host):\(self.port)")
            case .failed(let error):
                fatalError("Server failed: \(error)")
            default:
                break
            }
        }

        listener?.start(queue: queue)
    }

    public func stop() {
        listener?.cancel()
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.readRequest(from: connection)
            case .failed, .cancelled:
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    private func readRequest(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: Self.maxBodySize) { [weak self] data, _, _, error in
            guard let self = self else { return }

            guard let data = data, !data.isEmpty else {
                connection.cancel()
                return
            }

            if let error = error {
                fputs("Connection error: \(error)\n", stderr)
                connection.cancel()
                return
            }

            guard let request = self.parseHTTPRequest(data: data) else {
                let response = HTTPResponse.error("Malformed HTTP request", status: 400)
                self.sendResponse(response, on: connection)
                return
            }

            // Check body size
            if let body = request.body, body.count > Self.maxBodySize {
                let response = HTTPResponse.error("Request body too large", status: 413)
                self.sendResponse(response, on: connection)
                return
            }

            // Auth check
            if let authResponse = self.checkAuth(request) {
                self.sendResponse(authResponse, on: connection)
                return
            }

            let response = self.router.handle(request)
            self.sendResponse(response, on: connection)
        }
    }

    private func checkAuth(_ request: HTTPRequest) -> HTTPResponse? {
        // Skip auth for health check, docs, and OpenAPI spec
        let publicPaths = ["/health", "/docs", "/openapi.yaml", "/app"]
        if request.method == "GET" && publicPaths.contains(request.path) {
            return nil
        }

        guard let authHeader = request.headers["authorization"] else {
            return .error("Missing Authorization header", status: 401)
        }

        let prefix = "bearer "
        guard authHeader.lowercased().hasPrefix(prefix) else {
            return .error("Invalid Authorization header format. Expected: Bearer <key>", status: 401)
        }

        let token = String(authHeader.dropFirst(prefix.count))
        guard let permission = keyStore.getPermission(token) else {
            return .error("Invalid API key", status: 401)
        }

        if permission == "read" && request.method != "GET" {
            return .error("Read-only API key", status: 403, code: "forbidden")
        }

        return nil
    }

    func parseHTTPRequest(data: Data) -> HTTPRequest? {
        guard let str = String(data: data, encoding: .utf8) else { return nil }

        // Split headers from body
        guard let headerEndRange = str.range(of: "\r\n\r\n") else { return nil }
        let headerSection = String(str[str.startIndex..<headerEndRange.lowerBound])
        let bodyStart = headerEndRange.upperBound

        // Parse request line
        let lines = headerSection.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2 else { return nil }

        let method = String(parts[0])
        let fullPath = String(parts[1])

        // Split path and query string
        let pathComponents = fullPath.split(separator: "?", maxSplits: 1)
        let path = String(pathComponents[0])
        var queryParams: [String: String] = [:]

        if pathComponents.count > 1 {
            let queryString = String(pathComponents[1])
            for param in queryString.split(separator: "&") {
                let kv = param.split(separator: "=", maxSplits: 1)
                if kv.count == 2 {
                    let key = String(kv[0]).removingPercentEncoding ?? String(kv[0])
                    let value = String(kv[1]).removingPercentEncoding ?? String(kv[1])
                    queryParams[key] = value
                } else if kv.count == 1 {
                    queryParams[String(kv[0])] = ""
                }
            }
        }

        // Parse headers
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if let colonIdx = line.firstIndex(of: ":") {
                let key = String(line[line.startIndex..<colonIdx]).trimmingCharacters(in: .whitespaces).lowercased()
                let value = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }

        // Extract body
        var body: Data?
        if bodyStart < str.endIndex {
            let bodyString = String(str[bodyStart...])
            if !bodyString.isEmpty {
                body = bodyString.data(using: .utf8)
            }
        }

        return HTTPRequest(
            method: method,
            path: path,
            queryParams: queryParams,
            headers: headers,
            body: body
        )
    }

    private func sendResponse(_ response: HTTPResponse, on connection: NWConnection) {
        var headerStr = "HTTP/1.1 \(response.status) \(response.statusText)\r\n"

        var headers = response.headers
        headers["Connection"] = "close"
        if let body = response.body {
            headers["Content-Length"] = "\(body.count)"
        } else {
            headers["Content-Length"] = "0"
        }

        for (key, value) in headers {
            headerStr += "\(key): \(value)\r\n"
        }
        headerStr += "\r\n"

        var responseData = Data(headerStr.utf8)
        if let body = response.body {
            responseData.append(body)
        }

        connection.send(content: responseData, completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }
}

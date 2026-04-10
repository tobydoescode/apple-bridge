import Foundation

public typealias RouteHandler = @Sendable (HTTPRequest) -> HTTPResponse

struct Route: Sendable {
    let method: String
    let pathPattern: String
    let segments: [String]
    let handler: RouteHandler
}

public final class Router: @unchecked Sendable {
    private var routes: [Route] = []

    public init() {}

    public func get(_ path: String, handler: @escaping RouteHandler) {
        addRoute("GET", path, handler: handler)
    }

    public func post(_ path: String, handler: @escaping RouteHandler) {
        addRoute("POST", path, handler: handler)
    }

    public func put(_ path: String, handler: @escaping RouteHandler) {
        addRoute("PUT", path, handler: handler)
    }

    public func patch(_ path: String, handler: @escaping RouteHandler) {
        addRoute("PATCH", path, handler: handler)
    }

    public func delete(_ path: String, handler: @escaping RouteHandler) {
        addRoute("DELETE", path, handler: handler)
    }

    private func addRoute(_ method: String, _ path: String, handler: @escaping RouteHandler) {
        let segments = path.split(separator: "/").map(String.init)
        routes.append(Route(method: method, pathPattern: path, segments: segments, handler: handler))
    }

    public func handle(_ request: HTTPRequest) -> HTTPResponse {
        let requestSegments = request.path.split(separator: "/").map(String.init)

        var pathMatched = false

        for route in routes {
            guard matchSegments(pattern: route.segments, actual: requestSegments) else {
                continue
            }
            pathMatched = true

            guard route.method == request.method else {
                continue
            }

            var req = request
            req.pathParams = extractParams(pattern: route.segments, actual: requestSegments)
            return route.handler(req)
        }

        if pathMatched {
            return .error("Method \(request.method) not allowed for \(request.path)", status: 405)
        }

        return .error("Not found: \(request.path)", status: 404)
    }

    private func matchSegments(pattern: [String], actual: [String]) -> Bool {
        guard pattern.count == actual.count else { return false }
        for (p, a) in zip(pattern, actual) {
            if p.hasPrefix(":") { continue }
            if p != a { return false }
        }
        return true
    }

    private func extractParams(pattern: [String], actual: [String]) -> [String: String] {
        var params: [String: String] = [:]
        for (p, a) in zip(pattern, actual) {
            if p.hasPrefix(":") {
                params[String(p.dropFirst())] = a
            }
        }
        return params
    }
}

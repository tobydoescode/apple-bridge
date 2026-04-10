import Foundation

public struct HTTPRequest: Sendable {
    public let method: String
    public let path: String
    public let queryParams: [String: String]
    public let headers: [String: String]
    public let body: Data?
    public var pathParams: [String: String] = [:]

    public init(method: String, path: String, queryParams: [String: String], headers: [String: String], body: Data?, pathParams: [String: String] = [:]) {
        self.method = method
        self.path = path
        self.queryParams = queryParams
        self.headers = headers
        self.body = body
        self.pathParams = pathParams
    }
}

public struct HTTPResponse: Sendable {
    public let status: Int
    public let statusText: String
    public let headers: [String: String]
    public let body: Data?

    public init(status: Int, statusText: String, headers: [String: String] = [:], body: Data? = nil) {
        self.status = status
        self.statusText = statusText
        self.headers = headers
        self.body = body
    }

    public static func json<T: Encodable>(_ value: T, status: Int = 200) -> HTTPResponse {
        let statusText = statusTextFor(status)
        do {
            let data = try JSON.encode(value)
            return HTTPResponse(
                status: status,
                statusText: statusText,
                headers: ["Content-Type": "application/json"],
                body: data
            )
        } catch {
            return .error("Failed to encode response: \(error.localizedDescription)", status: 500)
        }
    }

    public static func error(_ message: String, status: Int, code: String? = nil) -> HTTPResponse {
        let errorCode = code ?? errorCodeFor(status)
        let body = ErrorResponse(error: errorCode, message: message)
        do {
            let data = try JSON.encode(body)
            return HTTPResponse(
                status: status,
                statusText: statusTextFor(status),
                headers: ["Content-Type": "application/json"],
                body: data
            )
        } catch {
            let fallback = "{\"error\":\"\(errorCode)\",\"message\":\"\(message)\"}".data(using: .utf8)
            return HTTPResponse(
                status: status,
                statusText: statusTextFor(status),
                headers: ["Content-Type": "application/json"],
                body: fallback
            )
        }
    }

    public static func noContent() -> HTTPResponse {
        HTTPResponse(status: 204, statusText: "No Content")
    }

    private static func statusTextFor(_ status: Int) -> String {
        switch status {
        case 200: return "OK"
        case 201: return "Created"
        case 204: return "No Content"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 413: return "Payload Too Large"
        case 422: return "Unprocessable Entity"
        case 500: return "Internal Server Error"
        default: return "Unknown"
        }
    }

    private static func errorCodeFor(_ status: Int) -> String {
        switch status {
        case 400: return "bad_request"
        case 401: return "unauthorized"
        case 403: return "forbidden"
        case 404: return "not_found"
        case 405: return "method_not_allowed"
        case 413: return "payload_too_large"
        case 422: return "unprocessable_entity"
        case 500: return "internal_error"
        default: return "error"
        }
    }
}

struct ErrorResponse: Codable, Sendable {
    let error: String
    let message: String
}

public struct ListResponse<T: Codable>: Codable {
    public let items: [T]
    public let count: Int

    public init(items: [T]) {
        self.items = items
        self.count = items.count
    }
}

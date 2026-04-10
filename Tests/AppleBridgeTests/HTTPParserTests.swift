import Testing
import Foundation
@testable import AppleBridgeLib

@Suite("HTTP Parser Tests")
struct HTTPParserTests {
    private let server = HTTPServer(host: "127.0.0.1", port: 0, router: Router(), keyStore: APIKeyStore(configDir: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("apple-bridge-test-\(UUID().uuidString)")))

    @Test("Parses GET request with path")
    func parseSimpleGet() {
        let raw = "GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n"
        let request = server.parseHTTPRequest(data: Data(raw.utf8))

        #expect(request != nil)
        #expect(request?.method == "GET")
        #expect(request?.path == "/health")
        #expect(request?.headers["host"] == "localhost")
        #expect(request?.body == nil || request?.body?.isEmpty == true)
    }

    @Test("Parses query parameters")
    func parseQueryParams() {
        let raw = "GET /reminders?completed=true&listId=abc123 HTTP/1.1\r\nHost: localhost\r\n\r\n"
        let request = server.parseHTTPRequest(data: Data(raw.utf8))

        #expect(request != nil)
        #expect(request?.path == "/reminders")
        #expect(request?.queryParams["completed"] == "true")
        #expect(request?.queryParams["listId"] == "abc123")
    }

    @Test("Parses POST request with JSON body")
    func parsePostWithBody() {
        let body = "{\"title\":\"Test\"}"
        let raw = "POST /reminders HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\n\r\n\(body)"
        let request = server.parseHTTPRequest(data: Data(raw.utf8))

        #expect(request != nil)
        #expect(request?.method == "POST")
        #expect(request?.path == "/reminders")
        #expect(request?.headers["content-type"] == "application/json")
        #expect(request?.body == Data(body.utf8))
    }

    @Test("Headers are case-insensitive")
    func headersCaseInsensitive() {
        let raw = "GET /health HTTP/1.1\r\nAuthorization: Bearer abc\r\nContent-Type: application/json\r\n\r\n"
        let request = server.parseHTTPRequest(data: Data(raw.utf8))

        #expect(request?.headers["authorization"] == "Bearer abc")
        #expect(request?.headers["content-type"] == "application/json")
    }

    @Test("Returns nil for malformed request")
    func malformedRequest() {
        let raw = "GARBAGE DATA"
        let request = server.parseHTTPRequest(data: Data(raw.utf8))
        #expect(request == nil)
    }

    @Test("Parses URL-encoded query parameters")
    func urlEncodedParams() {
        let raw = "GET /events?startDate=2026-04-10T00%3A00%3A00Z HTTP/1.1\r\nHost: localhost\r\n\r\n"
        let request = server.parseHTTPRequest(data: Data(raw.utf8))

        #expect(request?.queryParams["startDate"] == "2026-04-10T00:00:00Z")
    }

    @Test("Parses DELETE request")
    func parseDelete() {
        let raw = "DELETE /reminders/abc123 HTTP/1.1\r\nHost: localhost\r\n\r\n"
        let request = server.parseHTTPRequest(data: Data(raw.utf8))

        #expect(request?.method == "DELETE")
        #expect(request?.path == "/reminders/abc123")
    }

    @Test("Parses PATCH request")
    func parsePatch() {
        let body = "{\"title\":\"Updated\"}"
        let raw = "PATCH /reminders/abc HTTP/1.1\r\nContent-Length: \(body.count)\r\n\r\n\(body)"
        let request = server.parseHTTPRequest(data: Data(raw.utf8))

        #expect(request?.method == "PATCH")
        #expect(request?.body == Data(body.utf8))
    }
}

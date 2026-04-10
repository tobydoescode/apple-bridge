import Testing
import Foundation
@testable import AppleBridgeLib

@Suite("Router Tests")
struct RouterTests {
    @Test("Matches simple GET route")
    func simpleGet() {
        let router = Router()
        router.get("/health") { _ in .json(["status": "ok"]) }

        let req = HTTPRequest(method: "GET", path: "/health", queryParams: [:], headers: [:], body: nil)
        let response = router.handle(req)

        #expect(response.status == 200)
    }

    @Test("Extracts path parameters")
    func pathParams() {
        let router = Router()
        // Verify param extraction via the response instead of capturing a var
        router.get("/reminders/:id") { req in
            return .json(["id": req.pathParams["id"] ?? ""])
        }

        let req = HTTPRequest(method: "GET", path: "/reminders/abc123", queryParams: [:], headers: [:], body: nil)
        let response = router.handle(req)

        #expect(response.status == 200)
        let body = try? JSON.decode([String: String].self, from: response.body!)
        #expect(body?["id"] == "abc123")
    }

    @Test("Returns 404 for unmatched path")
    func notFound() {
        let router = Router()
        router.get("/health") { _ in .json(["status": "ok"]) }

        let req = HTTPRequest(method: "GET", path: "/nonexistent", queryParams: [:], headers: [:], body: nil)
        let response = router.handle(req)

        #expect(response.status == 404)
    }

    @Test("Returns 405 for wrong method")
    func methodNotAllowed() {
        let router = Router()
        router.get("/health") { _ in .json(["status": "ok"]) }

        let req = HTTPRequest(method: "POST", path: "/health", queryParams: [:], headers: [:], body: nil)
        let response = router.handle(req)

        #expect(response.status == 405)
    }

    @Test("Matches multiple path parameters")
    func multipleParams() {
        let router = Router()
        router.get("/calendars/:calId/events/:eventId") { req in
            return .json(req.pathParams)
        }

        let req = HTTPRequest(method: "GET", path: "/calendars/cal1/events/evt2", queryParams: [:], headers: [:], body: nil)
        let response = router.handle(req)

        let body = try? JSON.decode([String: String].self, from: response.body!)
        #expect(body?["calId"] == "cal1")
        #expect(body?["eventId"] == "evt2")
    }

    @Test("Different methods on same path")
    func samePathDifferentMethods() {
        let router = Router()
        router.get("/reminders") { _ in HTTPResponse(status: 200, statusText: "OK") }
        router.post("/reminders") { _ in HTTPResponse(status: 201, statusText: "Created") }

        let getReq = HTTPRequest(method: "GET", path: "/reminders", queryParams: [:], headers: [:], body: nil)
        let postReq = HTTPRequest(method: "POST", path: "/reminders", queryParams: [:], headers: [:], body: nil)

        #expect(router.handle(getReq).status == 200)
        #expect(router.handle(postReq).status == 201)
    }

    @Test("Does not match different segment counts")
    func segmentCountMismatch() {
        let router = Router()
        router.get("/reminders/:id") { _ in HTTPResponse(status: 200, statusText: "OK") }

        let req = HTTPRequest(method: "GET", path: "/reminders", queryParams: [:], headers: [:], body: nil)
        let response = router.handle(req)

        #expect(response.status == 404)
    }

    @Test("Nested action routes")
    func nestedActionRoute() {
        let router = Router()
        router.post("/reminders/:id/complete") { req in
            return .json(["id": req.pathParams["id"] ?? ""])
        }

        let req = HTTPRequest(method: "POST", path: "/reminders/r123/complete", queryParams: [:], headers: [:], body: nil)
        let response = router.handle(req)

        #expect(response.status == 200)
        let body = try? JSON.decode([String: String].self, from: response.body!)
        #expect(body?["id"] == "r123")
    }
}

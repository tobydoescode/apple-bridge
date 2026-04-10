import Testing
import Foundation
@testable import AppleBridgeLib

@Suite("CLI Parser Tests")
struct CLIParserTests {
    @Test("No arguments defaults to serve")
    func defaultServe() {
        let cmd = CLIParser.parse(["apple-bridge"])
        guard case .serve(let host, let port, let statusBar) = cmd else {
            Issue.record("Expected .serve, got \(cmd)")
            return
        }
        #expect(host == "127.0.0.1")
        #expect(port == 23487)
        #expect(statusBar == false)
    }

    @Test("Serve with custom host and port")
    func serveCustom() {
        let cmd = CLIParser.parse(["apple-bridge", "serve", "--host", "0.0.0.0", "--port", "8080"])
        guard case .serve(let host, let port, let statusBar) = cmd else {
            Issue.record("Expected .serve")
            return
        }
        #expect(host == "0.0.0.0")
        #expect(port == 8080)
        #expect(statusBar == false)
    }

    @Test("Serve with status bar flag")
    func serveStatusBar() {
        let cmd = CLIParser.parse(["apple-bridge", "serve", "--status-bar"])
        guard case .serve(_, _, let statusBar) = cmd else {
            Issue.record("Expected .serve")
            return
        }
        #expect(statusBar == true)
    }

    @Test("Keys create without label")
    func keysCreateNoLabel() {
        let cmd = CLIParser.parse(["apple-bridge", "keys", "create"])
        guard case .keysCreate(let label, let readOnly) = cmd else {
            Issue.record("Expected .keysCreate")
            return
        }
        #expect(label == nil)
        #expect(readOnly == false)
    }

    @Test("Keys create with label")
    func keysCreateWithLabel() {
        let cmd = CLIParser.parse(["apple-bridge", "keys", "create", "--label", "test-key"])
        guard case .keysCreate(let label, let readOnly) = cmd else {
            Issue.record("Expected .keysCreate")
            return
        }
        #expect(label == "test-key")
        #expect(readOnly == false)
    }

    @Test("Keys create with readonly flag")
    func keysCreateReadOnly() {
        let cmd = CLIParser.parse(["apple-bridge", "keys", "create", "--label", "viewer", "--readonly"])
        guard case .keysCreate(let label, let readOnly) = cmd else {
            Issue.record("Expected .keysCreate")
            return
        }
        #expect(label == "viewer")
        #expect(readOnly == true)
    }

    @Test("Keys list")
    func keysList() {
        let cmd = CLIParser.parse(["apple-bridge", "keys", "list"])
        guard case .keysList = cmd else {
            Issue.record("Expected .keysList")
            return
        }
    }

    @Test("Keys revoke with id")
    func keysRevoke() {
        let cmd = CLIParser.parse(["apple-bridge", "keys", "revoke", "k_abc12345"])
        guard case .keysRevoke(let id) = cmd else {
            Issue.record("Expected .keysRevoke")
            return
        }
        #expect(id == "k_abc12345")
    }

    @Test("Serve with all options combined")
    func serveAllOptions() {
        let cmd = CLIParser.parse(["apple-bridge", "serve", "--host", "192.168.1.100", "--port", "9999", "--status-bar"])
        guard case .serve(let host, let port, let statusBar) = cmd else {
            Issue.record("Expected .serve")
            return
        }
        #expect(host == "192.168.1.100")
        #expect(port == 9999)
        #expect(statusBar == true)
    }
}

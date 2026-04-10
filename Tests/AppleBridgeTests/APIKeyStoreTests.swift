import Testing
import Foundation
@testable import AppleBridgeLib

@Suite("API Key Store Tests")
struct APIKeyStoreTests {
    private func makeTempStore() -> (APIKeyStore, URL) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("apple-bridge-test-\(UUID().uuidString)")
        return (APIKeyStore(configDir: dir), dir)
    }

    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    @Test("Create returns key with mb_ prefix")
    func createKeyPrefix() {
        let (store, dir) = makeTempStore()
        defer { cleanup(dir) }

        let key = store.create(label: nil)
        #expect(key.hasPrefix("mb_"))
    }

    @Test("Create returns 67-char key (mb_ + 64 hex)")
    func createKeyLength() {
        let (store, dir) = makeTempStore()
        defer { cleanup(dir) }

        let key = store.create(label: nil)
        #expect(key.count == 67) // "mb_" (3) + 64 hex chars
    }

    @Test("Verify succeeds with correct key")
    func verifyCorrectKey() {
        let (store, dir) = makeTempStore()
        defer { cleanup(dir) }

        let key = store.create(label: nil)
        #expect(store.verify(key))
    }

    @Test("Verify fails with wrong key")
    func verifyWrongKey() {
        let (store, dir) = makeTempStore()
        defer { cleanup(dir) }

        _ = store.create(label: nil)
        #expect(!store.verify("mb_0000000000000000000000000000000000000000000000000000000000000000"))
    }

    @Test("List returns created keys")
    func listKeys() {
        let (store, dir) = makeTempStore()
        defer { cleanup(dir) }

        _ = store.create(label: "first")
        _ = store.create(label: "second")

        let keys = store.list()
        #expect(keys.count == 2)
        #expect(keys[0].label == "first")
        #expect(keys[1].label == "second")
    }

    @Test("Revoke removes key")
    func revokeKey() {
        let (store, dir) = makeTempStore()
        defer { cleanup(dir) }

        _ = store.create(label: "keep")
        _ = store.create(label: "remove")

        let keys = store.list()
        let idToRevoke = keys.first { $0.label == "remove" }!.id

        #expect(store.revoke(id: idToRevoke))
        #expect(store.list().count == 1)
        #expect(store.list()[0].label == "keep")
    }

    @Test("Revoke returns false for unknown id")
    func revokeUnknown() {
        let (store, dir) = makeTempStore()
        defer { cleanup(dir) }

        #expect(!store.revoke(id: "k_nonexistent"))
    }

    @Test("Revoked key fails verification")
    func revokedKeyFails() {
        let (store, dir) = makeTempStore()
        defer { cleanup(dir) }

        let key = store.create(label: nil)
        let id = store.list()[0].id
        _ = store.revoke(id: id)
        #expect(!store.verify(key))
    }

    @Test("Keys persist across instances")
    func persistence() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("apple-bridge-test-\(UUID().uuidString)")
        defer { cleanup(dir) }

        let key: String
        do {
            let store1 = APIKeyStore(configDir: dir)
            key = store1.create(label: "persistent")
        }

        let store2 = APIKeyStore(configDir: dir)
        #expect(store2.verify(key))
        #expect(store2.list().count == 1)
        #expect(store2.list()[0].label == "persistent")
    }

    @Test("Key IDs have k_ prefix")
    func keyIdPrefix() {
        let (store, dir) = makeTempStore()
        defer { cleanup(dir) }

        _ = store.create(label: nil)
        let keys = store.list()
        #expect(keys[0].id.hasPrefix("k_"))
    }

    @Test("Default key has readwrite permission")
    func defaultPermission() {
        let (store, dir) = makeTempStore()
        defer { cleanup(dir) }

        let key = store.create(label: nil)
        #expect(store.getPermission(key) == "readwrite")
        #expect(store.list()[0].effectivePermission == "readwrite")
    }

    @Test("Read-only key has read permission")
    func readOnlyPermission() {
        let (store, dir) = makeTempStore()
        defer { cleanup(dir) }

        let key = store.create(label: nil, readOnly: true)
        #expect(store.getPermission(key) == "read")
        #expect(store.list()[0].effectivePermission == "read")
    }

    @Test("getPermission returns nil for invalid key")
    func getPermissionInvalid() {
        let (store, dir) = makeTempStore()
        defer { cleanup(dir) }

        #expect(store.getPermission("mb_invalid") == nil)
    }

    @Test("Keys without permission field default to readwrite")
    func backwardsCompatibility() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("apple-bridge-test-\(UUID().uuidString)")
        defer { cleanup(dir) }

        // Write a key without the permission field (simulating old format)
        let keysDir = dir.appendingPathComponent("keys.json")
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let oldFormat = "[{\"id\":\"k_test1234\",\"hash\":\"abc123\",\"createdAt\":\"2026-04-10T00:00:00Z\",\"label\":\"old\"}]"
        try! oldFormat.data(using: .utf8)!.write(to: keysDir)

        let store = APIKeyStore(configDir: dir)
        let keys = store.list()
        #expect(keys.count == 1)
        #expect(keys[0].effectivePermission == "readwrite")
    }
}

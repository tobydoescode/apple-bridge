import Foundation
import CryptoKit

public struct StoredKey: Codable {
    public let id: String
    public let hash: String
    public let createdAt: Date
    public let label: String?
    public let permission: String?

    public var effectivePermission: String {
        permission ?? "readwrite"
    }
}

public final class APIKeyStore: @unchecked Sendable {
    private let filePath: URL
    private var keys: [StoredKey] = []

    public init(configDir: URL? = nil) {
        let dir = configDir ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/apple-bridge")
        self.filePath = dir.appendingPathComponent("keys.json")
        loadKeys()
    }

    public func create(label: String?, readOnly: Bool = false) -> String {
        var randomBytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let plainKey = "mb_" + randomBytes.map { String(format: "%02x", $0) }.joined()

        let hash = hashKey(plainKey)
        let id = "k_" + String(hash.prefix(8))
        let permission = readOnly ? "read" : "readwrite"

        let stored = StoredKey(id: id, hash: hash, createdAt: Date(), label: label, permission: permission)
        keys.append(stored)
        saveKeys()

        return plainKey
    }

    public func verify(_ plainKey: String) -> Bool {
        let hash = hashKey(plainKey)
        return keys.contains { $0.hash == hash }
    }

    public func getPermission(_ plainKey: String) -> String? {
        let hash = hashKey(plainKey)
        guard let key = keys.first(where: { $0.hash == hash }) else { return nil }
        return key.effectivePermission
    }

    public func list() -> [StoredKey] {
        keys
    }

    public func revoke(id: String) -> Bool {
        let before = keys.count
        keys.removeAll { $0.id == id }
        if keys.count < before {
            saveKeys()
            return true
        }
        return false
    }

    private func hashKey(_ key: String) -> String {
        let data = Data(key.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func loadKeys() {
        guard FileManager.default.fileExists(atPath: filePath.path) else { return }
        do {
            let data = try Data(contentsOf: filePath)
            keys = try JSON.decode([StoredKey].self, from: data)
        } catch {
            fputs("Warning: Could not load API keys from \(filePath.path): \(error)\n", stderr)
        }
    }

    private func saveKeys() {
        let dir = filePath.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSON.encode(keys)
            try data.write(to: filePath, options: .atomic)
        } catch {
            fputs("Error: Could not save API keys to \(filePath.path): \(error)\n", stderr)
        }
    }
}

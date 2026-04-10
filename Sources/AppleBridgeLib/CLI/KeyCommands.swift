import Foundation

public enum KeyCommands {
    public static func create(label: String?, readOnly: Bool) {
        let store = APIKeyStore()
        let key = store.create(label: label, readOnly: readOnly)
        let permission = readOnly ? "read-only" : "read/write"
        print("API key created successfully (\(permission)).\n")
        print("Key: \(key)")
        print("\nStore this key securely — it cannot be retrieved again.")
    }

    public static func list() {
        let store = APIKeyStore()
        let keys = store.list()

        if keys.isEmpty {
            print("No API keys found. Create one with: apple-bridge keys create")
            return
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]

        print("API Keys:\n")
        for key in keys {
            let date = formatter.string(from: key.createdAt)
            let label = key.label.map { " (\($0))" } ?? ""
            let perm = key.effectivePermission == "read" ? "read-only" : "read/write"
            print("  \(key.id)\(label)  \(perm)  created: \(date)")
        }
        print("\nTotal: \(keys.count)")
    }

    public static func revoke(id: String) {
        let store = APIKeyStore()
        if store.revoke(id: id) {
            print("API key \(id) revoked.")
        } else {
            fputs("Error: No key found with id \(id)\n", stderr)
            exit(1)
        }
    }
}

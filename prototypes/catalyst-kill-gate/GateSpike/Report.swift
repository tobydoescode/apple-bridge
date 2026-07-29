import Foundation

/// Every check writes its verdict here; the HTTP probe serves the whole thing as
/// JSON. This is the spike's only output surface — "surface the state" — so that
/// one `curl` answers all five checks at once.
final class Report {
    static let shared = Report()

    private let queue = DispatchQueue(label: "gatespike.report")
    private var values: [String: Any] = [:]
    private var logLines: [String] = []
    private let started = Date()

    private init() {}

    func set(_ key: String, _ value: Any) {
        queue.sync { values[key] = value }
    }

    func append(log line: String) {
        let stamp = String(format: "%.3f", Date().timeIntervalSince(started))
        let entry = "[+\(stamp)s] \(line)"
        queue.sync { logLines.append(entry) }
        // Goes to launchd's StandardOutPath when running as an agent.
        print(entry)
        fflush(stdout)
    }

    func jsonData() -> Data {
        let snapshot: [String: Any] = queue.sync {
            var v = values
            v["uptime_seconds"] = Date().timeIntervalSince(started)
            v["pid"] = ProcessInfo.processInfo.processIdentifier
            v["log"] = logLines
            return v
        }
        return (try? JSONSerialization.data(
            withJSONObject: snapshot,
            options: [.prettyPrinted, .sortedKeys]
        )) ?? Data("{\"error\":\"serialisation failed\"}".utf8)
    }
}

func log(_ message: String) {
    Report.shared.append(log: message)
}

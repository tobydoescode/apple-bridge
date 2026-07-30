import Foundation
import Network

/// CHECK 2: bind a listening socket and serve HTTP from inside a sandboxed
/// Catalyst app, using the same `Network` framework the real daemon uses.
///
/// Requires `com.apple.security.network.server`. Without it, binding fails with
/// POSIXErrorCode 1 (EPERM) rather than the "address in use" you might expect —
/// worth knowing, because the two look nothing alike in the logs.
final class HTTPProbe {
    private var listener: NWListener?
    private let port: UInt16

    init(port: UInt16) {
        self.port = port
    }

    func start() {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        // Faithful to the real daemon: loopback only, never all interfaces.
        params.requiredLocalEndpoint = .hostPort(
            host: "127.0.0.1",
            port: NWEndpoint.Port(rawValue: port)!
        )

        do {
            let listener = try NWListener(using: params)
            self.listener = listener

            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    log("check2 listener ready on 127.0.0.1:\(self.port)")
                    Report.shared.set("check2_socket_bound", true)
                    Report.shared.set("check2_detail", "listening on 127.0.0.1:\(self.port)")
                case .failed(let error):
                    log("check2 listener FAILED: \(error)")
                    Report.shared.set("check2_socket_bound", false)
                    Report.shared.set("check2_detail", "failed: \(error)")
                case .cancelled:
                    log("check2 listener cancelled")
                default:
                    break
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                self?.serve(connection)
            }

            listener.start(queue: .global(qos: .userInitiated))
        } catch {
            log("check2 listener could not be created: \(error)")
            Report.shared.set("check2_socket_bound", false)
            Report.shared.set("check2_detail", "NWListener init threw: \(error)")
        }
    }

    /// Barely an HTTP server: pull the path out of the request line, dispatch,
    /// reply, close. No keep-alive, no headers parsed, no status codes but 200.
    /// Measurements can take minutes, so the reply is sent when they finish.
    private func serve(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, _, _ in
            let request = String(decoding: data ?? Data(), as: UTF8.self)
            let path = request
                .split(separator: "\r\n", maxSplits: 1).first
                .map { $0.split(separator: " ") }
                .flatMap { $0.count >= 2 ? String($0[1]) : nil } ?? "/"

            Task {
                let body = await MeasureRoutes.handle(path: path)
                var response = Data("""
                HTTP/1.1 200 OK\r
                Content-Type: application/json\r
                Content-Length: \(body.count)\r
                Connection: close\r
                \r

                """.utf8)
                response.append(body)

                connection.send(content: response, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
    }
}

/// Routes for apple-bridge#18. Each measurement is its own endpoint so they can
/// be run one at a time and compared, rather than all firing at launch.
enum MeasureRoutes {
    static func handle(path: String) async -> Data {
        let route = path.split(separator: "?").first.map(String.init) ?? "/"
        let query = path.split(separator: "?").dropFirst().first.map(String.init) ?? ""

        func intParam(_ name: String, _ fallback: Int) -> Int {
            for pair in query.split(separator: "&") {
                let kv = pair.split(separator: "=")
                if kv.count == 2, kv[0] == name, let v = Int(kv[1]) { return v }
            }
            return fallback
        }

        let probe = MeasureProbe.shared
        var payload: [String: Any]

        switch route {
        case "/":
            return Report.shared.jsonData()
        case "/measure/structure":
            payload = probe.structure()
        case "/measure/latency":
            payload = await probe.latencySample(count: intParam("n", 25))
        case "/measure/whole-house":
            payload = await probe.wholeHouse(concurrent: false)
        case "/measure/whole-house-concurrent":
            payload = await probe.wholeHouse(
                concurrent: true,
                concurrencyLimit: intParam("limit", 8)
            )
        case "/measure/unreachable":
            payload = await probe.unreachableProbe()
        case "/measure/enable-notifications":
            payload = await probe.enableNotifications(limit: intParam("n", 40))
        case "/measure/watch":
            payload = probe.watchReport()
        case "/measure/write-scene":
            // The only mutating route. Requires confirm=yes so it cannot be hit
            // by accident, and the scene is deleted again unless keep=1.
            if query.contains("confirm=yes") {
                payload = await probe.writeSceneCost(
                    deviceCount: intParam("devices", 5),
                    keep: intParam("keep", 0) == 1
                )
            } else {
                payload = ["error": "refusing to write", "hint": "add confirm=yes"]
            }
        default:
            payload = [
                "error": "unknown route",
                "routes": [
                    "/", "/measure/structure", "/measure/latency?n=25",
                    "/measure/whole-house", "/measure/whole-house-concurrent?limit=8",
                    "/measure/unreachable", "/measure/enable-notifications?n=40",
                    "/measure/watch",
                ],
            ]
        }

        payload["route"] = route

        // JSONSerialization RAISES an ObjC exception on an invalid object rather
        // than throwing, so `try?` does not save you — the process aborts. An
        // ArraySlice from .prefix() is invalid and killed this app once already.
        guard JSONSerialization.isValidJSONObject(payload) else {
            let types = payload.map { "\($0.key): \(type(of: $0.value))" }.sorted()
            log("INVALID JSON payload for \(route) — \(types)")
            return Data("{\"error\":\"invalid json payload\",\"types\":\"\(types)\"}".utf8)
        }
        return (try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        )) ?? Data("{\"error\":\"serialisation failed\"}".utf8)
    }
}

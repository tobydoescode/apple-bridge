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

    /// Deliberately the dumbest possible HTTP server: read whatever arrives,
    /// ignore it, reply with the report. No routing, no parsing, no keep-alive.
    private func serve(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { _, _, _, _ in
            let body = Report.shared.jsonData()
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

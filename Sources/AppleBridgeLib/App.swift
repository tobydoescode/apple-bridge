import Foundation
import Network

public enum AppleBridgeApp {
    public static func run() {
        let command = CLIParser.parse(CommandLine.arguments)

        switch command {
        case .serve(let host, let port, let statusBar):
            if isPortInUse(host: host, port: port) {
                fputs("Error: apple-bridge is already running on \(host):\(port)\n", stderr)
                exit(1)
            }

            let ekService = EventKitService()
            ekService.requestAccess()

            let keyStore = APIKeyStore()
            let router = Router()

            HealthRoutes.register(on: router, keyStore: keyStore)
            ReminderListRoutes.register(on: router, ekService: ekService)
            ReminderRoutes.register(on: router, ekService: ekService)
            CalendarRoutes.register(on: router, ekService: ekService)
            CalendarEventRoutes.register(on: router, ekService: ekService)

            let server = HTTPServer(host: host, port: port, router: router, keyStore: keyStore)
            server.start()

            if statusBar {
                MainActor.assumeIsolated {
                    StatusBarApp.run(server: server)
                }
            } else {
                dispatchMain()
            }

        case .keysCreate(let label, let readOnly):
            KeyCommands.create(label: label, readOnly: readOnly)
        case .keysList:
            KeyCommands.list()
        case .keysRevoke(let id):
            KeyCommands.revoke(id: id)
        }
    }

    private static func isPortInUse(host: String, port: UInt16) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var inUse = false

        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: .tcp
        )
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                inUse = true
                semaphore.signal()
            case .failed, .cancelled:
                semaphore.signal()
            default:
                break
            }
        }
        connection.start(queue: DispatchQueue(label: "port-check"))
        _ = semaphore.wait(timeout: .now() + 1)
        connection.cancel()
        return inUse
    }
}

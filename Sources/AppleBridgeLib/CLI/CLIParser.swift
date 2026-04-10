import Foundation

public enum Command {
    case serve(host: String, port: UInt16, statusBar: Bool)
    case keysCreate(label: String?, readOnly: Bool)
    case keysList
    case keysRevoke(id: String)
}

public enum CLIParser {
    public static func parse(_ arguments: [String]) -> Command {
        let args = Array(arguments.dropFirst()) // drop executable name

        guard let subcommand = args.first else {
            return .serve(host: "127.0.0.1", port: 23487, statusBar: false)
        }

        switch subcommand {
        case "serve":
            return parseServe(Array(args.dropFirst()))
        case "keys":
            return parseKeys(Array(args.dropFirst()))
        case "--help", "-h":
            printUsage()
            exit(0)
        default:
            fputs("Unknown command: \(subcommand)\n", stderr)
            printUsage()
            exit(1)
        }
    }

    private static func parseServe(_ args: [String]) -> Command {
        var host = "127.0.0.1"
        var port: UInt16 = 23487
        var statusBar = false
        var i = 0

        while i < args.count {
            switch args[i] {
            case "--host":
                i += 1
                guard i < args.count else {
                    fputs("--host requires a value\n", stderr)
                    exit(1)
                }
                host = args[i]
            case "--port":
                i += 1
                guard i < args.count, let p = UInt16(args[i]) else {
                    fputs("--port requires a valid port number\n", stderr)
                    exit(1)
                }
                port = p
            case "--status-bar":
                statusBar = true
            default:
                fputs("Unknown option: \(args[i])\n", stderr)
                exit(1)
            }
            i += 1
        }

        return .serve(host: host, port: port, statusBar: statusBar)
    }

    private static func parseKeys(_ args: [String]) -> Command {
        guard let action = args.first else {
            fputs("Usage: apple-bridge keys <create|list|revoke>\n", stderr)
            exit(1)
        }

        switch action {
        case "create":
            var label: String?
            var readOnly = false
            var i = 1
            while i < args.count {
                if args[i] == "--label" {
                    i += 1
                    guard i < args.count else {
                        fputs("--label requires a value\n", stderr)
                        exit(1)
                    }
                    label = args[i]
                } else if args[i] == "--readonly" {
                    readOnly = true
                }
                i += 1
            }
            return .keysCreate(label: label, readOnly: readOnly)
        case "list":
            return .keysList
        case "revoke":
            guard args.count > 1 else {
                fputs("Usage: apple-bridge keys revoke <id>\n", stderr)
                exit(1)
            }
            return .keysRevoke(id: args[1])
        default:
            fputs("Unknown keys action: \(action)\n", stderr)
            exit(1)
        }
    }

    public static func printUsage() {
        let usage = """
        apple-bridge — EventKit HTTP API server

        Usage:
          apple-bridge [serve] [options]    Start the API server (default)
          apple-bridge keys create [--label <name>] [--readonly]  Create an API key
          apple-bridge keys list             List API keys
          apple-bridge keys revoke <id>      Revoke an API key

        Server options:
          --host <address>    Bind address (default: 127.0.0.1)
          --port <port>       Port number (default: 23487)
          --status-bar        Show menu bar icon (macOS GUI mode)

        """
        print(usage)
    }
}

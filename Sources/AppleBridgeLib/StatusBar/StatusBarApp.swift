import AppKit

@MainActor
public enum StatusBarApp {
    private static var statusItem: NSStatusItem?

    public static func run(server: HTTPServer) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "AB"

        let menu = NSMenu()
        menu.addItem(withTitle: "apple-bridge", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Listening on \(server.host):\(server.port)", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem?.menu = menu

        app.run()
    }
}

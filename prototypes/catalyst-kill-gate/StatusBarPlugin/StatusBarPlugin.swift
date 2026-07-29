import AppKit

// Native macOS (AppKit) code, compiled for the macosx SDK, packaged as a .bundle,
// copied into the Catalyst app's Contents/PlugIns, and dlopen'd at runtime.
//
// This exists because AppKit.framework ships ONLY in the macOS slice of the SDK.
// A Mac Catalyst target cannot link it, so NSStatusItem is unreachable from
// Catalyst code. Loading a macOS bundle into the Catalyst process is Apple's
// documented escape hatch.
@objc(GSStatusBarPlugin)
final class StatusBarPlugin: NSObject, GatePluginProtocol {
    private var statusItem: NSStatusItem?
    private var quitHandler: (() -> Void)?

    func setQuitHandler(_ handler: @escaping @convention(block) () -> Void) {
        quitHandler = handler
    }

    @objc private func quitPressed() {
        NSLog("[plugin] quit pressed — handing off to the Catalyst side")
        quitHandler?()
    }

    func showStatusItem(title: String) -> Bool {
        // NSStatusBar is main-thread-only. The caller guarantees main.
        guard Thread.isMainThread else {
            NSLog("[plugin] showStatusItem called off main thread — refusing")
            return false
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = item.button else {
            NSLog("[plugin] statusItem has no button")
            return false
        }
        button.title = title

        let menu = NSMenu()
        menu.addItem(
            withTitle: "GateSpike — Catalyst kill-gate",
            action: nil,
            keyEquivalent: ""
        )
        menu.addItem(.separator())

        // MEASURED FINDING: #selector(NSApplication.terminate(_:)) here does NOT
        // reliably quit a Catalyst process. The first invocation surfaces the
        // Catalyst host window instead of terminating, and it takes a second
        // click to actually exit.
        //
        // So the menu item calls back into the Catalyst side, which exits
        // deterministically. AppKit is not asked to terminate anything.
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quitPressed),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        item.menu = menu

        statusItem = item
        NSLog("[plugin] status item created, title=%@", title)
        return true
    }

    func updateTitle(_ title: String) {
        statusItem?.button?.title = title
    }

    func activationPolicyDescription() -> String {
        switch NSApplication.shared.activationPolicy() {
        case .regular:    return "regular"      // dock icon present — LSUIElement ignored
        case .accessory:  return "accessory"    // no dock icon — LSUIElement honoured
        case .prohibited: return "prohibited"   // fully headless, no status bar possible
        @unknown default: return "unknown"
        }
    }

    func appKitWindowCount() -> Int {
        NSApplication.shared.windows.count
    }
}

import Foundation

/// CHECK 4: load the macOS AppKit bundle into this Catalyst process and get a
/// status bar item out of it.
///
/// The bundle lives in Contents/PlugIns, built for the macosx SDK while the host
/// app is built for maccatalyst. Same architecture, different platform in the
/// Mach-O build version — dlopen across that boundary is the whole basis of
/// Apple's AppKit-bundle pattern.
final class StatusBarBridge {
    private var plugin: GatePluginProtocol?

    func load(title: String) {
        precondition(Thread.isMainThread)

        guard let plugInsURL = Bundle.main.builtInPlugInsURL else {
            fail("Bundle.main.builtInPlugInsURL is nil")
            return
        }

        let bundleURL = plugInsURL.appendingPathComponent("StatusBarPlugin.bundle")
        Report.shared.set("check4_bundle_path", bundleURL.path)

        guard FileManager.default.fileExists(atPath: bundleURL.path) else {
            fail("plugin bundle missing at \(bundleURL.path) — copy phase did not run")
            return
        }

        guard let bundle = Bundle(url: bundleURL) else {
            fail("Bundle(url:) returned nil")
            return
        }

        // The interesting failure. If the plugin was accidentally built for
        // maccatalyst rather than macosx, or vice versa, it dies here.
        do {
            try bundle.loadAndReturnError()
        } catch {
            fail("bundle.load failed: \(error)")
            return
        }

        guard let principal = bundle.principalClass as? NSObject.Type else {
            fail("principalClass missing or not an NSObject subclass — check NSPrincipalClass in the plugin Info.plist")
            return
        }

        guard let plugin = principal.init() as? GatePluginProtocol else {
            fail("principal class does not conform to GSStatusBarPluginProtocol — likely an @objc protocol name mismatch between the two copies")
            return
        }

        self.plugin = plugin

        let shown = plugin.showStatusItem(title: title)
        Report.shared.set("check4_status_item_shown", shown)
        Report.shared.set("check4_detail", shown ? "NSStatusItem created from Catalyst process" : "plugin loaded but showStatusItem returned false")
        log("check4 plugin loaded, status item shown=\(shown)")

        // The plugin is the only code here that can see AppKit, so it answers
        // check 1 objectively rather than by inference.
        let policy = plugin.activationPolicyDescription()
        let windows = plugin.appKitWindowCount()
        Report.shared.set("check1_activation_policy", policy)
        Report.shared.set("check1_appkit_window_count", windows)
        Report.shared.set("check1_no_dock_icon", policy == "accessory" || policy == "prohibited")
        log("check1 activationPolicy=\(policy) appKitWindows=\(windows)")
    }

    func updateTitle(_ title: String) {
        plugin?.updateTitle(title)
    }

    private func fail(_ reason: String) {
        log("check4 FAILED: \(reason)")
        Report.shared.set("check4_status_item_shown", false)
        Report.shared.set("check4_detail", reason)
    }
}

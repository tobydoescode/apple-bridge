import UIKit

/// Classic UIApplicationDelegate with NO scene manifest, so UIKit creates no
/// window. Half of CHECK 1; the other half is whether LaunchServices honours
/// LSUIElement for a Catalyst bundle, which the AppKit plugin reports.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    private let httpProbe = HTTPProbe(port: 23499)
    private let homeKitProbe = HomeKitProbe()
    private let statusBar = StatusBarBridge()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        log("GateSpike launched — pid \(ProcessInfo.processInfo.processIdentifier)")

        Report.shared.set("bundle_id", Bundle.main.bundleIdentifier ?? "?")
        Report.shared.set("bundle_path", Bundle.main.bundlePath)
        Report.shared.set("lsuielement_declared", Bundle.main.infoDictionary?["LSUIElement"] as? Bool ?? false)
        Report.shared.set("scene_manifest_present", Bundle.main.infoDictionary?["UIApplicationSceneManifest"] != nil)
        Report.shared.set("connected_scenes", application.connectedScenes.count)
        Report.shared.set("launched_by_launchd", ProcessInfo.processInfo.environment["GATESPIKE_VIA_LAUNCHD"] == "1")
        Report.shared.set("sandboxed", ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil)
        Report.shared.set("home_dir", NSHomeDirectory())

        log("connectedScenes=\(application.connectedScenes.count) sandboxHome=\(NSHomeDirectory())")

        // CHECK 2 — socket. Started first so the report is reachable even if a
        // later check crashes the process.
        httpProbe.start()

        // CHECK 4 (and CHECK 1's objective half) — AppKit plugin bundle.
        statusBar.load(title: "GS")

        // CHECK 3 — live HomeKit.
        homeKitProbe.start()

        return true
    }

    // If a scene ever does get created, that itself is a finding — record it.
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        log("WARNING: UIKit asked for a scene configuration — a window may appear")
        Report.shared.set("check1_scene_requested", true)
        return UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
    }
}

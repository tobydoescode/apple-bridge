import Foundation
import HomeKit

/// CHECK 3: hold a live HMHomeManager in a windowless, launchd-started process
/// and actually read the home.
///
/// READ ONLY. This spike never writes to HomeKit — no scene is created, renamed
/// or deleted. It runs against a real household, so the safe move is to touch
/// nothing.
final class HomeKitProbe: NSObject, HMHomeManagerDelegate {
    private var manager: HMHomeManager?
    private let startedAt = Date()

    /// HMHomeManager must be constructed on the main thread.
    func start() {
        precondition(Thread.isMainThread)
        let manager = HMHomeManager()
        manager.delegate = self
        self.manager = manager

        log("check3 HMHomeManager created, auth=\(Self.describe(manager.authorizationStatus))")
        Report.shared.set("check3_authorization", Self.describe(manager.authorizationStatus))
        Report.shared.set("check3_homes_loaded", false)
    }

    // MARK: - HMHomeManagerDelegate

    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        let elapsed = Date().timeIntervalSince(startedAt)
        log("check3 homeManagerDidUpdateHomes after \(String(format: "%.2f", elapsed))s, homes=\(manager.homes.count)")

        Report.shared.set("check3_homes_loaded", true)
        Report.shared.set("check3_time_to_homes_seconds", elapsed)
        Report.shared.set("check3_home_count", manager.homes.count)
        Report.shared.set("check3_authorization", Self.describe(manager.authorizationStatus))

        guard let home = manager.primaryHome else {
            log("check3 no primaryHome")
            Report.shared.set("check3_primary_home", NSNull())
            return
        }

        // Counts only — cheap, and no characteristic reads. Measuring the cost of
        // reading values is a different ticket.
        let userScenes = home.actionSets.filter { $0.actionSetType == HMActionSetTypeUserDefined }

        Report.shared.set("check3_primary_home", home.name)
        Report.shared.set("check3_room_count", home.rooms.count)
        Report.shared.set("check3_accessory_count", home.accessories.count)
        Report.shared.set("check3_zone_count", home.zones.count)
        Report.shared.set("check3_action_set_count", home.actionSets.count)
        Report.shared.set("check3_user_scene_count", userScenes.count)
        Report.shared.set("check3_user_scene_names", userScenes.map { $0.name })
        Report.shared.set(
            "check3_unreachable_accessories",
            home.accessories.filter { !$0.isReachable }.map { $0.name }
        )

        log("check3 home=\(home.name) rooms=\(home.rooms.count) accessories=\(home.accessories.count) userScenes=\(userScenes.count)")
    }

    func homeManager(
        _ manager: HMHomeManager,
        didUpdate status: HMHomeManagerAuthorizationStatus
    ) {
        log("check3 authorization changed: \(Self.describe(status))")
        Report.shared.set("check3_authorization", Self.describe(status))
    }

    private static func describe(_ status: HMHomeManagerAuthorizationStatus) -> String {
        var parts: [String] = []
        if status.contains(.authorized) { parts.append("authorized") }
        if status.contains(.determined) { parts.append("determined") }
        if status.contains(.restricted) { parts.append("restricted") }
        return parts.isEmpty ? "none(raw:\(status.rawValue))" : parts.joined(separator: "+")
    }
}

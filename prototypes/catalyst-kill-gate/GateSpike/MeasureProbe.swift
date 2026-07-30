import Foundation
import HomeKit

/// Measurement harness for apple-bridge#18 — what does reading this house cost?
///
/// READ ONLY unless explicitly enabled. Every measurement here reads; nothing
/// writes. The write-cost measurement is a separate, guarded path.
final class MeasureProbe: NSObject, HMHomeDelegate, HMAccessoryDelegate {
    static let shared = MeasureProbe()

    private let lock = NSLock()
    private var home: HMHome?
    private var events: [[String: Any]] = []
    private var watchStarted: Date?

    struct ReadResult {
        let ok: Bool
        let seconds: Double
        let error: String?
    }

    // MARK: - Wiring

    /// Called once the home is available. Installs delegates on the home and on
    /// every accessory so external mutations can be observed (item 7).
    func attach(home: HMHome) {
        lock.lock(); self.home = home; watchStarted = Date(); lock.unlock()
        home.delegate = self
        for accessory in home.accessories {
            accessory.delegate = self
        }
        log("measure attached: home delegate + \(home.accessories.count) accessory delegates")
    }

    private func currentHome() -> HMHome? {
        lock.lock(); defer { lock.unlock() }
        return home
    }

    // MARK: - The PoC's snapshot filter

    /// Exactly the PoC design's rule: parent service is user-interactive,
    /// characteristic is readable AND writable, type is not Identify or Name.
    private func snapshotEligible(_ accessory: HMAccessory) -> [HMCharacteristic] {
        accessory.services
            .filter { $0.isUserInteractive }
            .flatMap { $0.characteristics }
            .filter { c in
                c.properties.contains(HMCharacteristicPropertyReadable)
                    && c.properties.contains(HMCharacteristicPropertyWritable)
                    && c.characteristicType != HMCharacteristicTypeIdentify
                    && c.characteristicType != HMCharacteristicTypeName
            }
    }

    /// Everything merely readable — the set a `GET /accessories` that inlined
    /// values would actually have to fetch. Wider than the snapshot filter.
    private func readable(_ accessory: HMAccessory) -> [HMCharacteristic] {
        accessory.services
            .flatMap { $0.characteristics }
            .filter { $0.properties.contains(HMCharacteristicPropertyReadable) }
    }

    // MARK: - One read, with a hard timeout

    /// `readValue` on an unreachable accessory may never call back, so every read
    /// races a timeout. Resume-once is enforced because resuming a continuation
    /// twice traps.
    private func read(_ characteristic: HMCharacteristic, timeout: Double) async -> ReadResult {
        let start = Date()
        let label = "\(characteristic.service?.accessory?.name ?? "?")/\(characteristic.localizedDescription)"
        log("read BEGIN \(label)")
        return await withCheckedContinuation { continuation in
            let guardLock = NSLock()
            var resumed = false

            func finish(_ result: ReadResult) {
                guardLock.lock()
                let isFirst = !resumed
                resumed = true
                guardLock.unlock()
                if isFirst { continuation.resume(returning: result) }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                finish(ReadResult(
                    ok: false,
                    seconds: Date().timeIntervalSince(start),
                    error: "TIMEOUT after \(timeout)s"
                ))
            }

            DispatchQueue.main.async {
                log("read CALLING readValue")
                characteristic.readValue { error in
                    log("read RETURNED err=\(error.map { "\($0)" } ?? "nil")")
                    finish(ReadResult(
                        ok: error == nil,
                        seconds: Date().timeIntervalSince(start),
                        error: error.map { "\($0)" }
                    ))
                }
            }
        }
    }

    // MARK: - Item 2: structure only, no characteristic reads

    func structure() -> [String: Any] {
        guard let home = currentHome() else { return ["error": "no home"] }
        let start = Date()

        var services = 0, characteristics = 0, eligible = 0, readableCount = 0
        var reachable = 0, unreachable = 0
        var perAccessoryEligible: [Int] = []

        for accessory in home.accessories {
            services += accessory.services.count
            characteristics += accessory.services.reduce(0) { $0 + $1.characteristics.count }
            let e = snapshotEligible(accessory).count
            eligible += e
            perAccessoryEligible.append(e)
            readableCount += readable(accessory).count
            if accessory.isReachable { reachable += 1 } else { unreachable += 1 }
        }

        let elapsed = Date().timeIntervalSince(start)
        return [
            "elapsed_seconds": elapsed,
            "homes": 1,
            "rooms": home.rooms.count,
            "zones": home.zones.count,
            "accessories": home.accessories.count,
            "accessories_reachable": reachable,
            "accessories_unreachable": unreachable,
            "unreachable_names": home.accessories.filter { !$0.isReachable }.map { $0.name },
            "services": services,
            "characteristics_total": characteristics,
            "characteristics_readable": readableCount,
            "characteristics_snapshot_eligible": eligible,
            "max_eligible_on_one_accessory": perAccessoryEligible.max() ?? 0,
            "action_sets": home.actionSets.count,
            "user_scenes": home.actionSets.filter { $0.actionSetType == HMActionSetTypeUserDefined }.count,
            "note": "no readValue calls made",
        ]
    }

    // MARK: - Item 3: per-characteristic latency on reachable accessories

    func latencySample(count: Int, timeout: Double = 10) async -> [String: Any] {
        guard let home = currentHome() else { return ["error": "no home"] }
        let candidates = home.accessories
            .filter { $0.isReachable }
            .flatMap { snapshotEligible($0) }
            .prefix(count)

        let start = Date()
        var results: [ReadResult] = []
        for characteristic in candidates {
            results.append(await read(characteristic, timeout: timeout))
        }
        return summarise(results, wall: Date().timeIntervalSince(start), extra: [
            "mode": "serial",
            "sampled": results.count,
        ])
    }

    // MARK: - Items 4 and 6: whole-house read, serial vs concurrent

    func wholeHouse(concurrent: Bool, concurrencyLimit: Int = 8, timeout: Double = 10) async -> [String: Any] {
        guard let home = currentHome() else { return ["error": "no home"] }
        // Reachable only. Unreachable accessories are measured separately so their
        // timeouts do not dominate this number.
        let targets = home.accessories.filter { $0.isReachable }.flatMap { snapshotEligible($0) }
        let start = Date()
        var results: [ReadResult] = []

        if concurrent {
            results = await withTaskGroup(of: ReadResult.self) { group in
                var collected: [ReadResult] = []
                var index = 0
                let inFlightCap = min(concurrencyLimit, targets.count)

                while index < inFlightCap {
                    let c = targets[index]
                    group.addTask { await self.read(c, timeout: timeout) }
                    index += 1
                }
                while let result = await group.next() {
                    collected.append(result)
                    if index < targets.count {
                        let c = targets[index]
                        group.addTask { await self.read(c, timeout: timeout) }
                        index += 1
                    }
                }
                return collected
            }
        } else {
            for characteristic in targets {
                results.append(await read(characteristic, timeout: timeout))
            }
        }

        return summarise(results, wall: Date().timeIntervalSince(start), extra: [
            "mode": concurrent ? "concurrent(limit:\(concurrencyLimit))" : "serial",
            "targets": targets.count,
        ])
    }

    // MARK: - Item 5: how do unreachable accessories fail?

    func unreachableProbe(timeout: Double = 15) async -> [String: Any] {
        guard let home = currentHome() else { return ["error": "no home"] }
        let offline = home.accessories.filter { !$0.isReachable }
        var perAccessory: [[String: Any]] = []

        for accessory in offline {
            guard let characteristic = snapshotEligible(accessory).first
                    ?? readable(accessory).first else {
                perAccessory.append([
                    "accessory": accessory.name,
                    "result": "no readable characteristic to try",
                ])
                continue
            }
            let result = await read(characteristic, timeout: timeout)
            perAccessory.append([
                "accessory": accessory.name,
                "room": accessory.room?.name ?? "—",
                "ok": result.ok,
                "seconds": result.seconds,
                "error": result.error ?? "none",
            ])
        }

        // Trust check in the other direction: do accessories that CLAIM to be
        // reachable actually answer? A sample is enough to spot a systemic lie.
        var falsePositives: [[String: Any]] = []
        for accessory in home.accessories.filter({ $0.isReachable }).prefix(25) {
            guard let characteristic = snapshotEligible(accessory).first else { continue }
            let result = await read(characteristic, timeout: timeout)
            if !result.ok {
                falsePositives.append([
                    "accessory": accessory.name,
                    "seconds": result.seconds,
                    "error": result.error ?? "unknown",
                ])
            }
        }

        return [
            "unreachable_count": offline.count,
            "unreachable_reads": perAccessory,
            "isReachable_false_positives_in_first_25_reachable": falsePositives,
            "isReachable_trustworthy_as_prefilter": falsePositives.isEmpty,
        ]
    }

    // MARK: - Item 8: write cost

    private static let measurePrefix = "MEASURE-DELETE-ME"

    /// Times `addActionSet` + N `addAction` for a realistic multi-accessory scene,
    /// then removes it.
    ///
    /// The ONLY writing path in this harness, and the only one that touches the
    /// real household. Deletion is guarded on the name prefix in this method, not
    /// at the call site, so a bug in routing cannot delete a real scene.
    func writeSceneCost(deviceCount: Int, keep: Bool, timeout: Double = 20) async -> [String: Any] {
        guard let home = currentHome() else { return ["error": "no home"] }

        // 1. Snapshot: one characteristic per accessory, current live value.
        let snapshotStart = Date()
        var captured: [(HMCharacteristic, NSCopying, String)] = []
        var snapshotFailures: [String] = []

        for accessory in home.accessories.filter({ $0.isReachable }) {
            if captured.count >= deviceCount { break }
            guard let characteristic = snapshotEligible(accessory).first else { continue }
            let result = await read(characteristic, timeout: timeout)
            guard result.ok, let value = characteristic.value as? NSCopying else {
                snapshotFailures.append(accessory.name)
                continue
            }
            captured.append((characteristic, value, accessory.name))
        }
        let snapshotSeconds = Date().timeIntervalSince(snapshotStart)

        guard !captured.isEmpty else {
            return ["error": "captured nothing", "snapshot_failures": snapshotFailures]
        }

        // 2. Create the empty action set.
        let name = "\(Self.measurePrefix) \(captured.count)"
        let createStart = Date()
        let created: HMActionSet? = await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                home.addActionSet(withName: name) { actionSet, error in
                    if let error = error { log("addActionSet failed: \(error)") }
                    continuation.resume(returning: actionSet)
                }
            }
        }
        let createSeconds = Date().timeIntervalSince(createStart)

        guard let actionSet = created else {
            return [
                "error": "addActionSet returned nil",
                "create_seconds": createSeconds,
                "snapshot_seconds": snapshotSeconds,
            ]
        }

        // 3. One addAction per captured value, timed individually.
        var addDurations: [Double] = []
        var addFailures: [String] = []
        let addAllStart = Date()

        for (characteristic, value, accessoryName) in captured {
            let start = Date()
            let error: Error? = await withCheckedContinuation { continuation in
                DispatchQueue.main.async {
                    let action = HMCharacteristicWriteAction(
                        characteristic: characteristic,
                        targetValue: value
                    )
                    actionSet.addAction(action) { error in
                        continuation.resume(returning: error)
                    }
                }
            }
            addDurations.append(Date().timeIntervalSince(start))
            if let error = error { addFailures.append("\(accessoryName): \(error.localizedDescription)") }
        }
        let addAllSeconds = Date().timeIntervalSince(addAllStart)

        // 4. Clean up, unless explicitly asked to keep it.
        var deleteSeconds: Double? = nil
        var deleted = false
        if !keep {
            guard actionSet.name.hasPrefix(Self.measurePrefix) else {
                return ["error": "refusing to delete '\(actionSet.name)' — prefix guard"]
            }
            let start = Date()
            let error: Error? = await withCheckedContinuation { continuation in
                DispatchQueue.main.async {
                    home.removeActionSet(actionSet) { error in
                        continuation.resume(returning: error)
                    }
                }
            }
            deleteSeconds = Date().timeIntervalSince(start)
            deleted = error == nil
            if let error = error { log("removeActionSet failed: \(error)") }
        }

        let sorted = addDurations.sorted()
        return [
            "scene_name": name,
            "accessories_captured": captured.count,
            "snapshot_seconds": snapshotSeconds,
            "snapshot_failures": snapshotFailures,
            "create_action_set_seconds": createSeconds,
            "add_action_count": addDurations.count,
            "add_action_total_seconds": addAllSeconds,
            "add_action_median_seconds": sorted.isEmpty ? 0 : sorted[sorted.count / 2],
            "add_action_max_seconds": sorted.last ?? 0,
            "add_action_failures": addFailures,
            "delete_seconds": deleteSeconds ?? -1,
            "deleted": deleted,
            "total_seconds": snapshotSeconds + createSeconds + addAllSeconds + (deleteSeconds ?? 0),
            "round_trips": 1 + addDurations.count + captured.count + (keep ? 0 : 1),
        ]
    }

    // MARK: - Item 7 prerequisite: characteristic notifications

    /// `accessory(_:service:didUpdateValueFor:)` does NOT fire just because a
    /// delegate is set — notifications must be enabled per characteristic, and
    /// only where `supportsEventNotification` is true. Without this, a physically
    /// flipped switch is invisible and any conclusion about a change stream would
    /// be wrong.
    func enableNotifications(limit: Int, timeout: Double = 10) async -> [String: Any] {
        guard let home = currentHome() else { return ["error": "no home"] }

        let candidates = home.accessories
            .filter { $0.isReachable }
            .flatMap { accessory in
                accessory.services
                    .filter { $0.isUserInteractive }
                    .flatMap { $0.characteristics }
                    .filter { $0.properties.contains(HMCharacteristicPropertySupportsEventNotification) }
            }
            .prefix(limit)

        var enabled = 0
        var failures: [String] = []
        let start = Date()

        for characteristic in candidates {
            let ok: Bool = await withCheckedContinuation { continuation in
                let guardLock = NSLock()
                var resumed = false
                func finish(_ value: Bool) {
                    guardLock.lock(); let first = !resumed; resumed = true; guardLock.unlock()
                    if first { continuation.resume(returning: value) }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { finish(false) }
                DispatchQueue.main.async {
                    characteristic.enableNotification(true) { error in
                        if let error = error {
                            failures.append("\(characteristic.localizedDescription): \(error.localizedDescription)")
                        }
                        finish(error == nil)
                    }
                }
            }
            if ok { enabled += 1 }
        }

        return [
            "attempted": candidates.count,
            "enabled": enabled,
            "failed": candidates.count - enabled,
            "elapsed_seconds": Date().timeIntervalSince(start),
            "distinct_failures": Array(Array(Set(failures)).prefix(5)),
            "note": "now change something in Home.app or flip a physical switch, then GET /measure/watch",
        ]
    }

    // MARK: - Item 7: did external mutations produce delegate callbacks?

    func watchReport() -> [String: Any] {
        lock.lock(); defer { lock.unlock() }
        return [
            "watching_since_seconds_ago": watchStarted.map { Date().timeIntervalSince($0) } ?? 0,
            "event_count": events.count,
            "events": events,
        ]
    }

    private func record(_ kind: String, _ detail: String) {
        let event: [String: Any] = [
            "at_seconds": watchStarted.map { Date().timeIntervalSince($0) } ?? 0,
            "kind": kind,
            "detail": detail,
        ]
        lock.lock(); events.append(event); lock.unlock()
        log("EVENT \(kind): \(detail)")
    }

    private func summarise(_ results: [ReadResult], wall: Double, extra: [String: Any]) -> [String: Any] {
        let okResults = results.filter { $0.ok }
        let durations = results.map { $0.seconds }.sorted()
        func pct(_ p: Double) -> Double {
            guard !durations.isEmpty else { return 0 }
            let idx = min(durations.count - 1, max(0, Int((Double(durations.count - 1) * p).rounded())))
            return durations[idx]
        }
        var out: [String: Any] = [
            "wall_clock_seconds": wall,
            "calls": results.count,
            "succeeded": okResults.count,
            "failed": results.count - okResults.count,
            "median_seconds": pct(0.5),
            "p95_seconds": pct(0.95),
            "max_seconds": durations.last ?? 0,
            "min_seconds": durations.first ?? 0,
            "calls_per_second": wall > 0 ? Double(results.count) / wall : 0,
            "distinct_errors": Array(Array(Set(results.compactMap { $0.error })).prefix(6)),
        ]
        extra.forEach { out[$0.key] = $0.value }
        return out
    }

    // MARK: - HMHomeDelegate (external mutation observation)

    func home(_ home: HMHome, didAdd actionSet: HMActionSet) { record("scene_added", actionSet.name) }
    func home(_ home: HMHome, didRemove actionSet: HMActionSet) { record("scene_removed", actionSet.name) }
    func home(_ home: HMHome, didAdd room: HMRoom) { record("room_added", room.name) }
    func home(_ home: HMHome, didRemove room: HMRoom) { record("room_removed", room.name) }
    func home(_ home: HMHome, didUpdateNameFor room: HMRoom) { record("room_renamed", room.name) }
    func home(_ home: HMHome, didUpdateNameFor accessory: HMAccessory) { record("accessory_renamed", accessory.name) }
    func home(_ home: HMHome, didAdd accessory: HMAccessory) {
        accessory.delegate = self
        record("accessory_added", accessory.name)
    }
    func home(_ home: HMHome, didRemove accessory: HMAccessory) { record("accessory_removed", accessory.name) }
    func home(_ home: HMHome, didUpdate room: HMRoom, for accessory: HMAccessory) {
        record("accessory_moved_room", "\(accessory.name) -> \(room.name)")
    }
    func homeDidUpdateName(_ home: HMHome) { record("home_renamed", home.name) }

    // MARK: - HMAccessoryDelegate

    func accessoryDidUpdateName(_ accessory: HMAccessory) {
        record("accessory_name_delegate", accessory.name)
    }

    func accessoryDidUpdateReachability(_ accessory: HMAccessory) {
        record("reachability_changed", "\(accessory.name) reachable=\(accessory.isReachable)")
    }

    /// The one that decides whether a push-based change stream is possible:
    /// does a physically-flipped switch reach us?
    func accessory(
        _ accessory: HMAccessory,
        service: HMService,
        didUpdateValueFor characteristic: HMCharacteristic
    ) {
        record(
            "characteristic_value_changed",
            "\(accessory.name)/\(service.name)/\(characteristic.localizedDescription) = \(String(describing: characteristic.value))"
        )
    }
}

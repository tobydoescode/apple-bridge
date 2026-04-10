import EventKit
import Foundation

public final class EventKitService: @unchecked Sendable {
    public let store = EKEventStore()

    public init() {}

    public func requestAccess() {
        let semaphore = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var errors: [String] = []

        store.requestFullAccessToReminders { granted, error in
            if !granted {
                errors.append("Reminders: \(error?.localizedDescription ?? "access denied")")
            }
            semaphore.signal()
        }
        semaphore.wait()

        store.requestFullAccessToEvents { granted, error in
            if !granted {
                errors.append("Calendars: \(error?.localizedDescription ?? "access denied")")
            }
            semaphore.signal()
        }
        semaphore.wait()

        if !errors.isEmpty {
            fputs("EventKit access denied:\n", stderr)
            for err in errors {
                fputs("  - \(err)\n", stderr)
            }
            fputs("\nGrant access in System Settings > Privacy & Security > Reminders/Calendars\n", stderr)
            exit(1)
        }

        print("EventKit access granted (Reminders + Calendars)")
    }
}

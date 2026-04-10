import EventKit
import Foundation

public final class ReminderListService: @unchecked Sendable {
    private let store: EKEventStore

    public init(store: EKEventStore) {
        self.store = store
    }

    public func list() -> [ReminderListResponse] {
        let calendars = store.calendars(for: .reminder)
        let defaultCal = store.defaultCalendarForNewReminders()
        return calendars.map { toResponse($0, isDefault: $0 == defaultCal) }
    }

    public func get(id: String) -> ReminderListResponse? {
        guard let cal = store.calendar(withIdentifier: id),
              cal.allowedEntityTypes.contains(.reminder) else { return nil }
        let defaultCal = store.defaultCalendarForNewReminders()
        return toResponse(cal, isDefault: cal == defaultCal)
    }

    public func create(_ input: CreateReminderListRequest) throws -> ReminderListResponse {
        let cal = EKCalendar(for: .reminder, eventStore: store)
        cal.title = input.title

        if let colorHex = input.color {
            cal.cgColor = cgColorFromHex(colorHex)
        }

        // Use the default source for reminders
        if let source = store.defaultCalendarForNewReminders()?.source {
            cal.source = source
        } else if let source = store.sources.first(where: { $0.sourceType == .local }) {
            cal.source = source
        }

        try store.saveCalendar(cal, commit: true)
        return toResponse(cal, isDefault: false)
    }

    public func update(id: String, _ input: UpdateReminderListRequest) throws -> ReminderListResponse? {
        guard let cal = store.calendar(withIdentifier: id),
              cal.allowedEntityTypes.contains(.reminder) else { return nil }

        if let title = input.title {
            cal.title = title
        }
        if let colorHex = input.color {
            cal.cgColor = cgColorFromHex(colorHex)
        }

        try store.saveCalendar(cal, commit: true)
        let defaultCal = store.defaultCalendarForNewReminders()
        return toResponse(cal, isDefault: cal == defaultCal)
    }

    public func delete(id: String) throws -> Bool {
        guard let cal = store.calendar(withIdentifier: id),
              cal.allowedEntityTypes.contains(.reminder) else { return false }
        try store.removeCalendar(cal, commit: true)
        return true
    }

    private func toResponse(_ cal: EKCalendar, isDefault: Bool) -> ReminderListResponse {
        ReminderListResponse(
            id: cal.calendarIdentifier,
            title: cal.title,
            color: hexFromCGColor(cal.cgColor),
            isDefault: isDefault,
            sourceTitle: cal.source.title
        )
    }
}

// MARK: - Color conversion

func cgColorFromHex(_ hex: String) -> CGColor {
    var hexStr = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if hexStr.hasPrefix("#") { hexStr = String(hexStr.dropFirst()) }

    guard hexStr.count == 6,
          let rgb = UInt32(hexStr, radix: 16) else {
        return CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    }

    let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
    let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
    let b = CGFloat(rgb & 0xFF) / 255.0
    return CGColor(red: r, green: g, blue: b, alpha: 1)
}

func hexFromCGColor(_ color: CGColor?) -> String? {
    guard let color = color,
          let components = color.components,
          components.count >= 3 else { return nil }
    let r = Int(components[0] * 255)
    let g = Int(components[1] * 255)
    let b = Int(components[2] * 255)
    return String(format: "#%02X%02X%02X", r, g, b)
}

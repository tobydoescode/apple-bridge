import EventKit
import Foundation

public final class CalendarService: @unchecked Sendable {
    private let store: EKEventStore

    public init(store: EKEventStore) {
        self.store = store
    }

    public func list() -> [CalendarResponse] {
        let calendars = store.calendars(for: .event)
        let defaultCal = store.defaultCalendarForNewEvents
        return calendars.map { toResponse($0, isDefault: $0 == defaultCal) }
    }

    public func get(id: String) -> CalendarResponse? {
        guard let cal = store.calendar(withIdentifier: id),
              cal.allowedEntityTypes.contains(.event) else { return nil }
        let defaultCal = store.defaultCalendarForNewEvents
        return toResponse(cal, isDefault: cal == defaultCal)
    }

    public func create(_ input: CreateCalendarRequest) throws -> CalendarResponse {
        let cal = EKCalendar(for: .event, eventStore: store)
        cal.title = input.title

        if let colorHex = input.color {
            cal.cgColor = cgColorFromHex(colorHex)
        }

        if let source = store.defaultCalendarForNewEvents?.source {
            cal.source = source
        } else if let source = store.sources.first(where: { $0.sourceType == .local }) {
            cal.source = source
        }

        try store.saveCalendar(cal, commit: true)
        return toResponse(cal, isDefault: false)
    }

    public func update(id: String, _ input: UpdateCalendarRequest) throws -> CalendarResponse? {
        guard let cal = store.calendar(withIdentifier: id),
              cal.allowedEntityTypes.contains(.event) else { return nil }

        if let title = input.title {
            cal.title = title
        }
        if let colorHex = input.color {
            cal.cgColor = cgColorFromHex(colorHex)
        }

        try store.saveCalendar(cal, commit: true)
        let defaultCal = store.defaultCalendarForNewEvents
        return toResponse(cal, isDefault: cal == defaultCal)
    }

    public func delete(id: String) throws -> Bool {
        guard let cal = store.calendar(withIdentifier: id),
              cal.allowedEntityTypes.contains(.event) else { return false }
        try store.removeCalendar(cal, commit: true)
        return true
    }

    private func toResponse(_ cal: EKCalendar, isDefault: Bool) -> CalendarResponse {
        CalendarResponse(
            id: cal.calendarIdentifier,
            title: cal.title,
            color: hexFromCGColor(cal.cgColor),
            type: "event",
            isDefault: isDefault,
            allowsContentModifications: cal.allowsContentModifications,
            sourceTitle: cal.source.title
        )
    }
}

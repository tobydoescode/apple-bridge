import EventKit
import Foundation
import CoreLocation

public final class ReminderService: @unchecked Sendable {
    private let store: EKEventStore

    public init(store: EKEventStore) {
        self.store = store
    }

    public func list(calendarId: String?, completed: Bool?, dueBefore: Date?, dueAfter: Date?, priority: Int?) -> [ReminderResponse] {
        let calendars: [EKCalendar]?
        if let calendarId = calendarId {
            if let cal = store.calendar(withIdentifier: calendarId) {
                calendars = [cal]
            } else {
                return []
            }
        } else {
            calendars = nil
        }

        let predicate = store.predicateForReminders(in: calendars)

        let semaphore = DispatchSemaphore(value: 0)
        var fetched: [EKReminder] = []
        store.fetchReminders(matching: predicate) { reminders in
            fetched = reminders ?? []
            semaphore.signal()
        }
        semaphore.wait()

        var results = fetched

        if let completed = completed {
            results = results.filter { $0.isCompleted == completed }
        }
        if let dueBefore = dueBefore {
            results = results.filter { reminder in
                guard let dueDate = reminder.dueDateComponents,
                      let date = Calendar.current.date(from: dueDate) else { return false }
                return date < dueBefore
            }
        }
        if let dueAfter = dueAfter {
            results = results.filter { reminder in
                guard let dueDate = reminder.dueDateComponents,
                      let date = Calendar.current.date(from: dueDate) else { return false }
                return date > dueAfter
            }
        }
        if let priority = priority {
            results = results.filter { $0.priority == priority }
        }

        return results.map { toResponse($0) }
    }

    public func get(id: String) -> ReminderResponse? {
        guard let item = store.calendarItem(withIdentifier: id) as? EKReminder else {
            return nil
        }
        return toResponse(item)
    }

    public func create(_ input: CreateReminderRequest) throws -> ReminderResponse {
        let reminder = EKReminder(eventStore: store)
        reminder.title = input.title
        reminder.notes = input.notes
        reminder.priority = input.priority ?? 0

        if let listId = input.listId, let cal = store.calendar(withIdentifier: listId) {
            reminder.calendar = cal
        } else {
            reminder.calendar = store.defaultCalendarForNewReminders()
        }

        if let dueDate = input.dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: dueDate
            )
        }

        if let urlStr = input.url, let url = URL(string: urlStr) {
            reminder.url = url
        }

        applyAlarms(input.alarms, to: reminder)
        applyRecurrenceRules(input.recurrenceRules, to: reminder)
        applyLocation(input.location, to: reminder)

        try store.save(reminder, commit: true)
        return toResponse(reminder)
    }

    public func update(id: String, _ input: UpdateReminderRequest, partial: Bool) throws -> ReminderResponse? {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else {
            return nil
        }

        if let title = input.title {
            reminder.title = title
        } else if !partial {
            reminder.title = ""
        }

        if let notes = input.notes {
            reminder.notes = notes
        } else if !partial {
            reminder.notes = nil
        }

        if let priority = input.priority {
            reminder.priority = priority
        } else if !partial {
            reminder.priority = 0
        }

        if let listId = input.listId, let cal = store.calendar(withIdentifier: listId) {
            reminder.calendar = cal
        }

        if let dueDate = input.dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: dueDate
            )
        } else if !partial {
            reminder.dueDateComponents = nil
        }

        if let urlStr = input.url {
            reminder.url = URL(string: urlStr)
        } else if !partial {
            reminder.url = nil
        }

        if input.alarms != nil || !partial {
            if let alarms = reminder.alarms {
                for alarm in alarms { reminder.removeAlarm(alarm) }
            }
            applyAlarms(input.alarms, to: reminder)
        }

        if input.recurrenceRules != nil || !partial {
            if let rules = reminder.recurrenceRules {
                for rule in rules { reminder.removeRecurrenceRule(rule) }
            }
            applyRecurrenceRules(input.recurrenceRules, to: reminder)
        }

        if input.location != nil || !partial {
            applyLocation(input.location, to: reminder)
        }

        try store.save(reminder, commit: true)
        return toResponse(reminder)
    }

    public func delete(id: String) throws -> Bool {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else {
            return false
        }
        try store.remove(reminder, commit: true)
        return true
    }

    public func complete(id: String) throws -> ReminderResponse? {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else {
            return nil
        }
        reminder.isCompleted = true
        try store.save(reminder, commit: true)
        return toResponse(reminder)
    }

    public func uncomplete(id: String) throws -> ReminderResponse? {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else {
            return nil
        }
        reminder.isCompleted = false
        reminder.completionDate = nil
        try store.save(reminder, commit: true)
        return toResponse(reminder)
    }

    // MARK: - Helpers

    private func applyAlarms(_ alarms: [AlarmInput]?, to item: EKCalendarItem) {
        guard let alarms = alarms else { return }
        for alarm in alarms {
            if let offset = alarm.relativeOffset {
                item.addAlarm(EKAlarm(relativeOffset: offset))
            } else if let date = alarm.absoluteDate {
                item.addAlarm(EKAlarm(absoluteDate: date))
            }
        }
    }

    private func applyRecurrenceRules(_ rules: [RecurrenceRuleInput]?, to item: EKCalendarItem) {
        guard let rules = rules else { return }
        for rule in rules {
            guard let freq = parseFrequency(rule.frequency) else { continue }

            let daysOfWeek = rule.daysOfTheWeek?.compactMap { parseDayOfWeek($0) }
            let daysOfMonth = rule.daysOfTheMonth?.map { NSNumber(value: $0) }
            let months = rule.monthsOfTheYear?.map { NSNumber(value: $0) }

            var end: EKRecurrenceEnd?
            if let endDate = rule.end?.date {
                end = EKRecurrenceEnd(end: endDate)
            } else if let count = rule.end?.count {
                end = EKRecurrenceEnd(occurrenceCount: count)
            }

            let ekRule = EKRecurrenceRule(
                recurrenceWith: freq,
                interval: rule.interval,
                daysOfTheWeek: daysOfWeek,
                daysOfTheMonth: daysOfMonth,
                monthsOfTheYear: months,
                weeksOfTheYear: nil,
                daysOfTheYear: nil,
                setPositions: nil,
                end: end
            )
            item.addRecurrenceRule(ekRule)
        }
    }

    private func applyLocation(_ location: LocationInput?, to reminder: EKReminder) {
        guard let location = location else { return }
        let structuredLocation = EKStructuredLocation(title: location.title ?? "")
        structuredLocation.geoLocation = CLLocation(
            latitude: location.latitude,
            longitude: location.longitude
        )
        structuredLocation.radius = location.radius ?? 100

        let alarm = EKAlarm()
        alarm.structuredLocation = structuredLocation
        switch location.proximity?.lowercased() {
        case "enter":
            alarm.proximity = .enter
        case "leave":
            alarm.proximity = .leave
        default:
            alarm.proximity = .enter
        }
        reminder.addAlarm(alarm)
    }

    private func toResponse(_ reminder: EKReminder) -> ReminderResponse {
        var dueDate: Date?
        if let components = reminder.dueDateComponents {
            dueDate = Calendar.current.date(from: components)
        }

        return ReminderResponse(
            id: reminder.calendarItemIdentifier,
            title: reminder.title ?? "",
            notes: reminder.notes,
            listId: reminder.calendar.calendarIdentifier,
            listTitle: reminder.calendar.title,
            isCompleted: reminder.isCompleted,
            completionDate: reminder.completionDate,
            dueDate: dueDate,
            priority: reminder.priority,
            alarms: (reminder.alarms ?? []).compactMap { toAlarmResponse($0) },
            recurrenceRules: (reminder.recurrenceRules ?? []).map { toRecurrenceRuleResponse($0) },
            location: extractLocation(from: reminder),
            url: reminder.url?.absoluteString,
            creationDate: reminder.creationDate,
            lastModifiedDate: reminder.lastModifiedDate
        )
    }

    private func extractLocation(from item: EKCalendarItem) -> LocationResponse? {
        guard let alarm = item.alarms?.first(where: { $0.structuredLocation != nil }),
              let loc = alarm.structuredLocation,
              let geo = loc.geoLocation else { return nil }
        let proximity: String
        switch alarm.proximity {
        case .enter: proximity = "enter"
        case .leave: proximity = "leave"
        default: proximity = "none"
        }
        return LocationResponse(
            title: loc.title,
            latitude: geo.coordinate.latitude,
            longitude: geo.coordinate.longitude,
            radius: loc.radius,
            proximity: proximity
        )
    }
}

// MARK: - Shared EK conversion helpers

func toAlarmResponse(_ alarm: EKAlarm) -> AlarmResponse? {
    if alarm.structuredLocation != nil { return nil } // location alarm, not time alarm
    return AlarmResponse(
        relativeOffset: alarm.relativeOffset != 0 ? alarm.relativeOffset : nil,
        absoluteDate: alarm.absoluteDate
    )
}

func toRecurrenceRuleResponse(_ rule: EKRecurrenceRule) -> RecurrenceRuleResponse {
    let frequency: String
    switch rule.frequency {
    case .daily: frequency = "daily"
    case .weekly: frequency = "weekly"
    case .monthly: frequency = "monthly"
    case .yearly: frequency = "yearly"
    @unknown default: frequency = "unknown"
    }

    let daysOfWeek = rule.daysOfTheWeek?.map { dayToString($0.dayOfTheWeek) }
    let daysOfMonth = rule.daysOfTheMonth?.map { $0.intValue }
    let months = rule.monthsOfTheYear?.map { $0.intValue }

    return RecurrenceRuleResponse(
        frequency: frequency,
        interval: rule.interval,
        daysOfTheWeek: daysOfWeek,
        daysOfTheMonth: daysOfMonth,
        monthsOfTheYear: months,
        endDate: rule.recurrenceEnd?.endDate,
        endCount: rule.recurrenceEnd?.occurrenceCount
    )
}

func parseFrequency(_ str: String) -> EKRecurrenceFrequency? {
    switch str.lowercased() {
    case "daily": return .daily
    case "weekly": return .weekly
    case "monthly": return .monthly
    case "yearly": return .yearly
    default: return nil
    }
}

func parseDayOfWeek(_ str: String) -> EKRecurrenceDayOfWeek? {
    switch str.uppercased() {
    case "MO": return EKRecurrenceDayOfWeek(.monday)
    case "TU": return EKRecurrenceDayOfWeek(.tuesday)
    case "WE": return EKRecurrenceDayOfWeek(.wednesday)
    case "TH": return EKRecurrenceDayOfWeek(.thursday)
    case "FR": return EKRecurrenceDayOfWeek(.friday)
    case "SA": return EKRecurrenceDayOfWeek(.saturday)
    case "SU": return EKRecurrenceDayOfWeek(.sunday)
    default: return nil
    }
}

func dayToString(_ day: EKWeekday) -> String {
    switch day {
    case .monday: return "MO"
    case .tuesday: return "TU"
    case .wednesday: return "WE"
    case .thursday: return "TH"
    case .friday: return "FR"
    case .saturday: return "SA"
    case .sunday: return "SU"
    @unknown default: return "??"
    }
}

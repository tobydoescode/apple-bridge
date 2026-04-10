import EventKit
import Foundation

public final class CalendarEventService: @unchecked Sendable {
    private let store: EKEventStore

    public init(store: EKEventStore) {
        self.store = store
    }

    public func list(calendarId: String?, startDate: Date, endDate: Date) -> [CalendarEventResponse] {
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

        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        let events = store.events(matching: predicate)
        return events.map { toResponse($0) }
    }

    public func get(id: String) -> CalendarEventResponse? {
        guard let event = store.event(withIdentifier: id) else { return nil }
        return toResponse(event)
    }

    public func create(_ input: CreateCalendarEventRequest) throws -> CalendarEventResponse {
        let event = EKEvent(eventStore: store)
        event.title = input.title
        event.notes = input.notes
        event.startDate = input.startDate
        event.endDate = input.endDate
        event.isAllDay = input.isAllDay ?? false

        if let calendarId = input.calendarId, let cal = store.calendar(withIdentifier: calendarId) {
            event.calendar = cal
        } else {
            event.calendar = store.defaultCalendarForNewEvents
        }

        if let location = input.location {
            event.location = location
        }

        if let urlStr = input.url, let url = URL(string: urlStr) {
            event.url = url
        }

        if let availability = input.availability {
            event.availability = parseAvailability(availability)
        }

        applyAlarms(input.alarms, to: event)
        applyRecurrenceRules(input.recurrenceRules, to: event)

        try store.save(event, span: .thisEvent)
        return toResponse(event)
    }

    public func update(id: String, _ input: UpdateCalendarEventRequest, partial: Bool) throws -> CalendarEventResponse? {
        guard let event = store.event(withIdentifier: id) else { return nil }

        if let title = input.title {
            event.title = title
        } else if !partial {
            event.title = ""
        }

        if let notes = input.notes {
            event.notes = notes
        } else if !partial {
            event.notes = nil
        }

        if let startDate = input.startDate {
            event.startDate = startDate
        }
        if let endDate = input.endDate {
            event.endDate = endDate
        }
        if let isAllDay = input.isAllDay {
            event.isAllDay = isAllDay
        }

        if let calendarId = input.calendarId, let cal = store.calendar(withIdentifier: calendarId) {
            event.calendar = cal
        }

        if let location = input.location {
            event.location = location
        } else if !partial {
            event.location = nil
        }

        if let urlStr = input.url {
            event.url = URL(string: urlStr)
        } else if !partial {
            event.url = nil
        }

        if let availability = input.availability {
            event.availability = parseAvailability(availability)
        }

        if input.alarms != nil || !partial {
            if let alarms = event.alarms {
                for alarm in alarms { event.removeAlarm(alarm) }
            }
            applyAlarms(input.alarms, to: event)
        }

        if input.recurrenceRules != nil || !partial {
            if let rules = event.recurrenceRules {
                for rule in rules { event.removeRecurrenceRule(rule) }
            }
            applyRecurrenceRules(input.recurrenceRules, to: event)
        }

        try store.save(event, span: .thisEvent)
        return toResponse(event)
    }

    public func delete(id: String, span: String?) throws -> Bool {
        guard let event = store.event(withIdentifier: id) else { return false }
        let ekSpan: EKSpan = span == "future" ? .futureEvents : .thisEvent
        try store.remove(event, span: ekSpan)
        return true
    }

    // MARK: - Helpers

    private func applyAlarms(_ alarms: [AlarmInput]?, to event: EKEvent) {
        guard let alarms = alarms else { return }
        for alarm in alarms {
            if let offset = alarm.relativeOffset {
                event.addAlarm(EKAlarm(relativeOffset: offset))
            } else if let date = alarm.absoluteDate {
                event.addAlarm(EKAlarm(absoluteDate: date))
            }
        }
    }

    private func applyRecurrenceRules(_ rules: [RecurrenceRuleInput]?, to event: EKEvent) {
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
            event.addRecurrenceRule(ekRule)
        }
    }

    private func parseAvailability(_ str: String) -> EKEventAvailability {
        switch str.lowercased() {
        case "busy": return .busy
        case "free": return .free
        case "tentative": return .tentative
        case "unavailable": return .unavailable
        default: return .busy
        }
    }

    private func availabilityString(_ availability: EKEventAvailability) -> String {
        switch availability {
        case .busy: return "busy"
        case .free: return "free"
        case .tentative: return "tentative"
        case .unavailable: return "unavailable"
        default: return "busy"
        }
    }

    private func statusString(_ status: EKEventStatus) -> String {
        switch status {
        case .confirmed: return "confirmed"
        case .tentative: return "tentative"
        case .canceled: return "canceled"
        default: return "none"
        }
    }

    private func participantStatusString(_ status: EKParticipantStatus) -> String {
        switch status {
        case .accepted: return "accepted"
        case .declined: return "declined"
        case .tentative: return "tentative"
        case .pending: return "pending"
        default: return "unknown"
        }
    }

    private func toResponse(_ event: EKEvent) -> CalendarEventResponse {
        let attendees: [AttendeeResponse] = (event.attendees ?? []).map { participant in
            AttendeeResponse(
                name: participant.name,
                email: participant.url.absoluteString.replacingOccurrences(of: "mailto:", with: ""),
                status: participantStatusString(participant.participantStatus)
            )
        }

        let organizer: String?
        if let org = event.organizer {
            organizer = org.name ?? org.url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
        } else {
            organizer = nil
        }

        return CalendarEventResponse(
            id: event.eventIdentifier,
            title: event.title ?? "",
            notes: event.notes,
            calendarId: event.calendar.calendarIdentifier,
            calendarTitle: event.calendar.title,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            location: event.location,
            url: event.url?.absoluteString,
            availability: availabilityString(event.availability),
            status: statusString(event.status),
            alarms: (event.alarms ?? []).compactMap { toAlarmResponse($0) },
            recurrenceRules: (event.recurrenceRules ?? []).map { toRecurrenceRuleResponse($0) },
            attendees: attendees,
            hasRecurrenceRules: event.hasRecurrenceRules,
            organizer: organizer,
            creationDate: event.creationDate,
            lastModifiedDate: event.lastModifiedDate
        )
    }
}

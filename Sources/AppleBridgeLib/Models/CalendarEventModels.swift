import Foundation

public struct CreateCalendarEventRequest: Codable {
    public let title: String
    public let notes: String?
    public let calendarId: String?
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool?
    public let location: String?
    public let url: String?
    public let availability: String? // "busy", "free", "tentative", "unavailable"
    public let alarms: [AlarmInput]?
    public let recurrenceRules: [RecurrenceRuleInput]?
}

public struct UpdateCalendarEventRequest: Codable {
    public let title: String?
    public let notes: String?
    public let calendarId: String?
    public let startDate: Date?
    public let endDate: Date?
    public let isAllDay: Bool?
    public let location: String?
    public let url: String?
    public let availability: String?
    public let alarms: [AlarmInput]?
    public let recurrenceRules: [RecurrenceRuleInput]?
}

public struct CalendarEventResponse: Codable {
    public let id: String
    public let title: String
    public let notes: String?
    public let calendarId: String
    public let calendarTitle: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let location: String?
    public let url: String?
    public let availability: String
    public let status: String
    public let alarms: [AlarmResponse]
    public let recurrenceRules: [RecurrenceRuleResponse]
    public let attendees: [AttendeeResponse]
    public let hasRecurrenceRules: Bool
    public let organizer: String?
    public let creationDate: Date?
    public let lastModifiedDate: Date?
}

public struct AttendeeResponse: Codable {
    public let name: String?
    public let email: String?
    public let status: String
}

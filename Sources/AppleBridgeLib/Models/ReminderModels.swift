import Foundation

public struct CreateReminderRequest: Codable {
    public let title: String
    public let notes: String?
    public let listId: String?
    public let dueDate: Date?
    public let priority: Int?
    public let alarms: [AlarmInput]?
    public let recurrenceRules: [RecurrenceRuleInput]?
    public let location: LocationInput?
    public let url: String?
}

public struct UpdateReminderRequest: Codable {
    public let title: String?
    public let notes: String?
    public let listId: String?
    public let dueDate: Date?
    public let priority: Int?
    public let alarms: [AlarmInput]?
    public let recurrenceRules: [RecurrenceRuleInput]?
    public let location: LocationInput?
    public let url: String?
}

public struct ReminderResponse: Codable {
    public let id: String
    public let title: String
    public let notes: String?
    public let listId: String
    public let listTitle: String
    public let isCompleted: Bool
    public let completionDate: Date?
    public let dueDate: Date?
    public let priority: Int
    public let alarms: [AlarmResponse]
    public let recurrenceRules: [RecurrenceRuleResponse]
    public let location: LocationResponse?
    public let url: String?
    public let creationDate: Date?
    public let lastModifiedDate: Date?
}

public struct ReminderListResponse: Codable {
    public let id: String
    public let title: String
    public let color: String?
    public let isDefault: Bool
    public let sourceTitle: String
}

public struct CreateReminderListRequest: Codable {
    public let title: String
    public let color: String?
}

public struct UpdateReminderListRequest: Codable {
    public let title: String?
    public let color: String?
}

import Foundation

public struct AlarmInput: Codable {
    public let relativeOffset: TimeInterval?
    public let absoluteDate: Date?
}

public struct AlarmResponse: Codable {
    public let relativeOffset: TimeInterval?
    public let absoluteDate: Date?
}

public struct RecurrenceRuleInput: Codable {
    public let frequency: String // "daily", "weekly", "monthly", "yearly"
    public let interval: Int
    public let daysOfTheWeek: [String]? // "MO","TU","WE","TH","FR","SA","SU"
    public let daysOfTheMonth: [Int]?
    public let monthsOfTheYear: [Int]?
    public let end: RecurrenceEndInput?
}

public struct RecurrenceEndInput: Codable {
    public let date: Date?
    public let count: Int?
}

public struct RecurrenceRuleResponse: Codable {
    public let frequency: String
    public let interval: Int
    public let daysOfTheWeek: [String]?
    public let daysOfTheMonth: [Int]?
    public let monthsOfTheYear: [Int]?
    public let endDate: Date?
    public let endCount: Int?
}

public struct LocationInput: Codable {
    public let title: String?
    public let latitude: Double
    public let longitude: Double
    public let radius: Double?
    public let proximity: String? // "enter", "leave", "none"
}

public struct LocationResponse: Codable {
    public let title: String?
    public let latitude: Double
    public let longitude: Double
    public let radius: Double
    public let proximity: String
}

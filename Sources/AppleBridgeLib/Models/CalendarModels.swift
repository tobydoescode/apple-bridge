import Foundation

public struct CalendarResponse: Codable {
    public let id: String
    public let title: String
    public let color: String?
    public let type: String
    public let isDefault: Bool
    public let allowsContentModifications: Bool
    public let sourceTitle: String
}

public struct CreateCalendarRequest: Codable {
    public let title: String
    public let color: String?
}

public struct UpdateCalendarRequest: Codable {
    public let title: String?
    public let color: String?
}

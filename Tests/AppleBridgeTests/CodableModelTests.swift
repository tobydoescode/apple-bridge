import Testing
import Foundation
@testable import AppleBridgeLib

@Suite("Codable Model Tests")
struct CodableModelTests {
    @Test("CreateReminderRequest round-trips")
    func reminderRequestRoundTrip() throws {
        let input = CreateReminderRequest(
            title: "Test",
            notes: "Some notes",
            listId: "list-123",
            dueDate: ISO8601DateFormatter().date(from: "2026-04-15T10:00:00Z"),
            priority: 1,
            alarms: [AlarmInput(relativeOffset: -3600, absoluteDate: nil)],
            recurrenceRules: [RecurrenceRuleInput(
                frequency: "daily",
                interval: 1,
                daysOfTheWeek: nil,
                daysOfTheMonth: nil,
                monthsOfTheYear: nil,
                end: RecurrenceEndInput(date: nil, count: 10)
            )],
            location: LocationInput(title: "Store", latitude: 37.77, longitude: -122.41, radius: 100, proximity: "enter"),
            url: "https://example.com"
        )

        let data = try JSON.encode(input)
        let decoded = try JSON.decode(CreateReminderRequest.self, from: data)

        #expect(decoded.title == "Test")
        #expect(decoded.notes == "Some notes")
        #expect(decoded.priority == 1)
        #expect(decoded.alarms?.count == 1)
        #expect(decoded.alarms?[0].relativeOffset == -3600)
        #expect(decoded.recurrenceRules?.count == 1)
        #expect(decoded.recurrenceRules?[0].frequency == "daily")
        #expect(decoded.location?.latitude == 37.77)
        #expect(decoded.url == "https://example.com")
    }

    @Test("UpdateReminderRequest with nil fields")
    func updateReminderPartial() throws {
        let json = "{\"title\":\"Updated\"}"
        let decoded = try JSON.decode(UpdateReminderRequest.self, from: Data(json.utf8))

        #expect(decoded.title == "Updated")
        #expect(decoded.notes == nil)
        #expect(decoded.priority == nil)
    }

    @Test("CreateCalendarEventRequest round-trips")
    func eventRequestRoundTrip() throws {
        let input = CreateCalendarEventRequest(
            title: "Meeting",
            notes: "Discuss plans",
            calendarId: "cal-1",
            startDate: ISO8601DateFormatter().date(from: "2026-04-15T09:00:00Z")!,
            endDate: ISO8601DateFormatter().date(from: "2026-04-15T10:00:00Z")!,
            isAllDay: false,
            location: "Room A",
            url: "https://meet.example.com",
            availability: "busy",
            alarms: [AlarmInput(relativeOffset: -600, absoluteDate: nil)],
            recurrenceRules: nil
        )

        let data = try JSON.encode(input)
        let decoded = try JSON.decode(CreateCalendarEventRequest.self, from: data)

        #expect(decoded.title == "Meeting")
        #expect(decoded.isAllDay == false)
        #expect(decoded.availability == "busy")
        #expect(decoded.location == "Room A")
    }

    @Test("ReminderResponse encodes dates as ISO 8601")
    func dateEncoding() throws {
        let response = ReminderResponse(
            id: "r1",
            title: "Test",
            notes: nil,
            listId: "l1",
            listTitle: "List",
            isCompleted: false,
            completionDate: nil,
            dueDate: ISO8601DateFormatter().date(from: "2026-04-15T10:00:00Z"),
            priority: 0,
            alarms: [],
            recurrenceRules: [],
            location: nil,
            url: nil,
            creationDate: nil,
            lastModifiedDate: nil
        )

        let data = try JSON.encode(response)
        let jsonStr = String(data: data, encoding: .utf8)!
        #expect(jsonStr.contains("2026-04-15T10:00:00Z"))
    }

    @Test("ListResponse wraps items with count")
    func listResponse() throws {
        let items = [
            CalendarResponse(
                id: "c1", title: "Work", color: "#FF0000",
                type: "event", isDefault: true,
                allowsContentModifications: true, sourceTitle: "iCloud"
            )
        ]
        let response = ListResponse(items: items)
        let data = try JSON.encode(response)
        let decoded = try JSON.decode(ListResponse<CalendarResponse>.self, from: data)

        #expect(decoded.count == 1)
        #expect(decoded.items[0].title == "Work")
    }

    @Test("ErrorResponse encodes correctly")
    func errorResponse() throws {
        let response = HTTPResponse.error("Not found", status: 404)
        #expect(response.status == 404)

        let body = try JSON.decode(ErrorResponse.self, from: response.body!)
        #expect(body.error == "not_found")
        #expect(body.message == "Not found")
    }

    @Test("AlarmInput with absolute date")
    func alarmAbsoluteDate() throws {
        let date = ISO8601DateFormatter().date(from: "2026-04-15T09:00:00Z")!
        let alarm = AlarmInput(relativeOffset: nil, absoluteDate: date)
        let data = try JSON.encode(alarm)
        let decoded = try JSON.decode(AlarmInput.self, from: data)

        #expect(decoded.absoluteDate == date)
        #expect(decoded.relativeOffset == nil)
    }

    @Test("RecurrenceRule with end count")
    func recurrenceWithCount() throws {
        let rule = RecurrenceRuleInput(
            frequency: "weekly",
            interval: 2,
            daysOfTheWeek: ["MO", "WE", "FR"],
            daysOfTheMonth: nil,
            monthsOfTheYear: nil,
            end: RecurrenceEndInput(date: nil, count: 52)
        )
        let data = try JSON.encode(rule)
        let decoded = try JSON.decode(RecurrenceRuleInput.self, from: data)

        #expect(decoded.frequency == "weekly")
        #expect(decoded.interval == 2)
        #expect(decoded.daysOfTheWeek == ["MO", "WE", "FR"])
        #expect(decoded.end?.count == 52)
    }
}

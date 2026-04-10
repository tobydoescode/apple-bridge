import Foundation

public enum CalendarEventRoutes {
    public static func register(on router: Router, ekService: EventKitService) {
        let service = CalendarEventService(store: ekService.store)

        router.get("/events") { req in
            let dateFormatter = ISO8601DateFormatter()
            guard let startStr = req.queryParams["startDate"],
                  let endStr = req.queryParams["endDate"],
                  let startDate = dateFormatter.date(from: startStr),
                  let endDate = dateFormatter.date(from: endStr) else {
                return .error("Required query params: startDate, endDate (ISO 8601)", status: 400)
            }
            let calendarId = req.queryParams["calendarId"]
            let items = service.list(calendarId: calendarId, startDate: startDate, endDate: endDate)
            return .json(ListResponse(items: items))
        }

        router.get("/events/:id") { req in
            guard let event = service.get(id: req.pathParams["id"]!) else {
                return .error("Event not found", status: 404)
            }
            return .json(event)
        }

        router.post("/events") { req in
            guard let body = req.body,
                  let input = try? JSON.decode(CreateCalendarEventRequest.self, from: body) else {
                return .error("Invalid request body", status: 400)
            }
            do {
                let event = try service.create(input)
                return .json(event, status: 201)
            } catch {
                return .error("Failed to create event: \(error.localizedDescription)", status: 500)
            }
        }

        router.put("/events/:id") { req in
            guard let body = req.body,
                  let input = try? JSON.decode(UpdateCalendarEventRequest.self, from: body) else {
                return .error("Invalid request body", status: 400)
            }
            do {
                guard let event = try service.update(id: req.pathParams["id"]!, input, partial: false) else {
                    return .error("Event not found", status: 404)
                }
                return .json(event)
            } catch {
                return .error("Failed to update event: \(error.localizedDescription)", status: 500)
            }
        }

        router.patch("/events/:id") { req in
            guard let body = req.body,
                  let input = try? JSON.decode(UpdateCalendarEventRequest.self, from: body) else {
                return .error("Invalid request body", status: 400)
            }
            do {
                guard let event = try service.update(id: req.pathParams["id"]!, input, partial: true) else {
                    return .error("Event not found", status: 404)
                }
                return .json(event)
            } catch {
                return .error("Failed to update event: \(error.localizedDescription)", status: 500)
            }
        }

        router.delete("/events/:id") { req in
            do {
                let span = req.queryParams["span"]
                guard try service.delete(id: req.pathParams["id"]!, span: span) else {
                    return .error("Event not found", status: 404)
                }
                return .noContent()
            } catch {
                return .error("Failed to delete event: \(error.localizedDescription)", status: 500)
            }
        }
    }
}

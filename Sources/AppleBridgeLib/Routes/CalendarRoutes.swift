import Foundation

public enum CalendarRoutes {
    public static func register(on router: Router, ekService: EventKitService) {
        let service = CalendarService(store: ekService.store)

        router.get("/calendars") { _ in
            let items = service.list()
            return .json(ListResponse(items: items))
        }

        router.get("/calendars/:id") { req in
            guard let cal = service.get(id: req.pathParams["id"]!) else {
                return .error("Calendar not found", status: 404)
            }
            return .json(cal)
        }

        router.post("/calendars") { req in
            guard let body = req.body,
                  let input = try? JSON.decode(CreateCalendarRequest.self, from: body) else {
                return .error("Invalid request body", status: 400)
            }
            do {
                let cal = try service.create(input)
                return .json(cal, status: 201)
            } catch {
                return .error("Failed to create calendar: \(error.localizedDescription)", status: 500)
            }
        }

        router.put("/calendars/:id") { req in
            guard let body = req.body,
                  let input = try? JSON.decode(UpdateCalendarRequest.self, from: body) else {
                return .error("Invalid request body", status: 400)
            }
            do {
                guard let cal = try service.update(id: req.pathParams["id"]!, input) else {
                    return .error("Calendar not found", status: 404)
                }
                return .json(cal)
            } catch {
                return .error("Failed to update calendar: \(error.localizedDescription)", status: 500)
            }
        }

        router.delete("/calendars/:id") { req in
            do {
                guard try service.delete(id: req.pathParams["id"]!) else {
                    return .error("Calendar not found", status: 404)
                }
                return .noContent()
            } catch {
                return .error("Failed to delete calendar: \(error.localizedDescription)", status: 500)
            }
        }
    }
}

import Foundation

public enum ReminderRoutes {
    public static func register(on router: Router, ekService: EventKitService) {
        let service = ReminderService(store: ekService.store)

        router.get("/reminders") { req in
            let completed: Bool?
            if let val = req.queryParams["completed"] {
                completed = val == "all" ? nil : Bool(val)
            } else {
                completed = false  // default: show only incomplete
            }
            let listId = req.queryParams["listId"]
            let dueBefore = req.queryParams["dueBefore"].flatMap { ISO8601DateFormatter().date(from: $0) }
            let dueAfter = req.queryParams["dueAfter"].flatMap { ISO8601DateFormatter().date(from: $0) }
            let priority = req.queryParams["priority"].flatMap { Int($0) }

            let items = service.list(
                calendarId: listId,
                completed: completed,
                dueBefore: dueBefore,
                dueAfter: dueAfter,
                priority: priority
            )
            return .json(ListResponse(items: items))
        }

        router.get("/reminders/:id") { req in
            guard let reminder = service.get(id: req.pathParams["id"]!) else {
                return .error("Reminder not found", status: 404)
            }
            return .json(reminder)
        }

        router.post("/reminders") { req in
            guard let body = req.body,
                  let input = try? JSON.decode(CreateReminderRequest.self, from: body) else {
                return .error("Invalid request body", status: 400)
            }
            do {
                let reminder = try service.create(input)
                return .json(reminder, status: 201)
            } catch {
                return .error("Failed to create reminder: \(error.localizedDescription)", status: 500)
            }
        }

        router.put("/reminders/:id") { req in
            guard let body = req.body,
                  let input = try? JSON.decode(UpdateReminderRequest.self, from: body) else {
                return .error("Invalid request body", status: 400)
            }
            do {
                guard let reminder = try service.update(id: req.pathParams["id"]!, input, partial: false) else {
                    return .error("Reminder not found", status: 404)
                }
                return .json(reminder)
            } catch {
                return .error("Failed to update reminder: \(error.localizedDescription)", status: 500)
            }
        }

        router.patch("/reminders/:id") { req in
            guard let body = req.body,
                  let input = try? JSON.decode(UpdateReminderRequest.self, from: body) else {
                return .error("Invalid request body", status: 400)
            }
            do {
                guard let reminder = try service.update(id: req.pathParams["id"]!, input, partial: true) else {
                    return .error("Reminder not found", status: 404)
                }
                return .json(reminder)
            } catch {
                return .error("Failed to update reminder: \(error.localizedDescription)", status: 500)
            }
        }

        router.delete("/reminders/:id") { req in
            do {
                guard try service.delete(id: req.pathParams["id"]!) else {
                    return .error("Reminder not found", status: 404)
                }
                return .noContent()
            } catch {
                return .error("Failed to delete reminder: \(error.localizedDescription)", status: 500)
            }
        }

        router.post("/reminders/:id/complete") { req in
            do {
                guard let reminder = try service.complete(id: req.pathParams["id"]!) else {
                    return .error("Reminder not found", status: 404)
                }
                return .json(reminder)
            } catch {
                return .error("Failed to complete reminder: \(error.localizedDescription)", status: 500)
            }
        }

        router.post("/reminders/:id/uncomplete") { req in
            do {
                guard let reminder = try service.uncomplete(id: req.pathParams["id"]!) else {
                    return .error("Reminder not found", status: 404)
                }
                return .json(reminder)
            } catch {
                return .error("Failed to uncomplete reminder: \(error.localizedDescription)", status: 500)
            }
        }
    }
}

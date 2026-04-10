import Foundation

public enum ReminderListRoutes {
    public static func register(on router: Router, ekService: EventKitService) {
        let service = ReminderListService(store: ekService.store)

        router.get("/reminder-lists") { _ in
            let items = service.list()
            return .json(ListResponse(items: items))
        }

        router.get("/reminder-lists/:id") { req in
            guard let list = service.get(id: req.pathParams["id"]!) else {
                return .error("Reminder list not found", status: 404)
            }
            return .json(list)
        }

        router.post("/reminder-lists") { req in
            guard let body = req.body,
                  let input = try? JSON.decode(CreateReminderListRequest.self, from: body) else {
                return .error("Invalid request body", status: 400)
            }
            do {
                let list = try service.create(input)
                return .json(list, status: 201)
            } catch {
                return .error("Failed to create reminder list: \(error.localizedDescription)", status: 500)
            }
        }

        router.put("/reminder-lists/:id") { req in
            guard let body = req.body,
                  let input = try? JSON.decode(UpdateReminderListRequest.self, from: body) else {
                return .error("Invalid request body", status: 400)
            }
            do {
                guard let list = try service.update(id: req.pathParams["id"]!, input) else {
                    return .error("Reminder list not found", status: 404)
                }
                return .json(list)
            } catch {
                return .error("Failed to update reminder list: \(error.localizedDescription)", status: 500)
            }
        }

        router.delete("/reminder-lists/:id") { req in
            do {
                guard try service.delete(id: req.pathParams["id"]!) else {
                    return .error("Reminder list not found", status: 404)
                }
                return .noContent()
            } catch {
                return .error("Failed to delete reminder list: \(error.localizedDescription)", status: 500)
            }
        }
    }
}

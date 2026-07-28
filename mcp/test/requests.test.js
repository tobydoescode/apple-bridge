import { after, afterEach, before, describe, test } from "node:test";
import assert from "node:assert/strict";
import { TOKEN, jsonOf, startFakeBridge, startMcpClient, textOf } from "./helpers.js";

// Exercises how tool calls are translated into HTTP requests against the Swift
// bridge: method, path, query string, body shape and error mapping.
describe("tool calls", () => {
  let bridge;
  let client;

  const call = (name, args = {}) =>
    client.callTool({ name, arguments: args });

  before(async () => {
    bridge = await startFakeBridge();
    client = await startMcpClient(bridge.url);
  });

  afterEach(() => bridge.reset());

  after(async () => {
    await client.close();
    await bridge.close();
  });

  test("sends the bearer token and JSON content type", async () => {
    await call("list_reminder_lists");
    assert.equal(bridge.last().authorization, `Bearer ${TOKEN}`);
    assert.equal(bridge.last().contentType, "application/json");
  });

  test("GET with no body", async () => {
    await call("list_calendars");
    assert.equal(bridge.last().method, "GET");
    assert.equal(bridge.last().url, "/calendars");
    assert.equal(bridge.last().body, undefined);
  });

  test("POST forwards the tool arguments as the request body", async () => {
    await call("create_reminder", {
      title: "Buy milk",
      notes: "semi-skimmed",
      priority: 1,
    });

    const req = bridge.last();
    assert.equal(req.method, "POST");
    assert.equal(req.url, "/reminders");
    assert.deepEqual(req.body, {
      title: "Buy milk",
      notes: "semi-skimmed",
      priority: 1,
    });
  });

  test("PATCH strips the id from the body and puts it in the path", async () => {
    await call("update_reminder", { id: "abc-123", title: "New title" });

    const req = bridge.last();
    assert.equal(req.method, "PATCH");
    assert.equal(req.url, "/reminders/abc-123");
    assert.deepEqual(req.body, { title: "New title" });
    assert.ok(!("id" in req.body), "id must not be duplicated into the body");
  });

  test("filters are serialised as query parameters", async () => {
    await call("list_reminders", {
      listId: "list-1",
      completed: false,
      priority: 0,
      dueBefore: "2026-01-01T00:00:00Z",
    });

    const [path, query] = bridge.last().url.split("?");
    assert.equal(path, "/reminders");

    const params = new URLSearchParams(query);
    assert.equal(params.get("listId"), "list-1");
    // false and 0 are falsy but meaningful - they must still be sent.
    assert.equal(params.get("completed"), "false");
    assert.equal(params.get("priority"), "0");
    assert.equal(params.get("dueBefore"), "2026-01-01T00:00:00Z");
  });

  test("omitted filters produce a bare path with no trailing ?", async () => {
    await call("list_reminders");
    assert.equal(bridge.last().url, "/reminders");
  });

  test("required date range is always sent for events", async () => {
    await call("list_events", {
      startDate: "2026-01-01T00:00:00Z",
      endDate: "2026-01-31T00:00:00Z",
    });

    const params = new URLSearchParams(bridge.last().url.split("?")[1]);
    assert.equal(params.get("startDate"), "2026-01-01T00:00:00Z");
    assert.equal(params.get("endDate"), "2026-01-31T00:00:00Z");
    assert.equal(params.get("calendarId"), null);
  });

  test("recurring event deletion passes the span through", async () => {
    await call("delete_event", { id: "evt-9", span: "future" });
    assert.equal(bridge.last().method, "DELETE");
    assert.equal(bridge.last().url, "/events/evt-9?span=future");

    bridge.reset();
    await call("delete_event", { id: "evt-9" });
    assert.equal(bridge.last().url, "/events/evt-9");
  });

  test("action endpoints POST to their sub-path", async () => {
    await call("complete_reminder", { id: "r-1" });
    assert.equal(bridge.last().method, "POST");
    assert.equal(bridge.last().url, "/reminders/r-1/complete");

    bridge.reset();
    await call("uncomplete_reminder", { id: "r-1" });
    assert.equal(bridge.last().url, "/reminders/r-1/uncomplete");
  });

  test("returns the bridge response as pretty-printed JSON", async () => {
    bridge.respondWith(200, { id: "r-1", title: "Buy milk" });
    const result = await call("get_reminder", { id: "r-1" });

    assert.ok(!result.isError);
    assert.deepEqual(jsonOf(result), { id: "r-1", title: "Buy milk" });
  });

  test("204 No Content becomes a success payload", async () => {
    bridge.respondWith(204);
    const result = await call("delete_reminder", { id: "r-1" });

    assert.ok(!result.isError);
    assert.deepEqual(jsonOf(result), { success: true });
  });

  test("error responses surface the bridge message", async () => {
    bridge.respondWith(404, { message: "Reminder not found" });
    const result = await call("get_reminder", { id: "nope" });

    assert.equal(result.isError, true);
    assert.equal(textOf(result), "Error: Reminder not found");
  });

  test("error responses without a message fall back to the status code", async () => {
    bridge.respondWith(500, {});
    const result = await call("get_reminder", { id: "nope" });

    assert.equal(result.isError, true);
    assert.equal(textOf(result), "Error: HTTP 500");
  });

  test("invalid arguments are rejected before any HTTP call", async () => {
    const result = await call("create_reminder", { title: 42 });

    assert.equal(result.isError, true);
    // Message wording comes from zod and shifts between versions; assert on the
    // JSON-RPC code and the fact that nothing reached the bridge instead.
    assert.match(textOf(result), /-32602/);
    assert.equal(bridge.requests.length, 0);
  });

  test("missing required arguments are rejected before any HTTP call", async () => {
    const result = await call("create_event", { title: "No dates" });

    assert.equal(result.isError, true);
    assert.equal(bridge.requests.length, 0);
  });
});

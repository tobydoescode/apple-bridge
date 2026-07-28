import { after, before, describe, test } from "node:test";
import assert from "node:assert/strict";
import { startFakeBridge, startMcpClient } from "./helpers.js";

// Guards the tool surface the server advertises. A zod major bump changes how
// schemas are generated, so these assertions are what catch that drift.
describe("tools/list", () => {
  let bridge;
  let client;
  let tools;

  before(async () => {
    bridge = await startFakeBridge();
    client = await startMcpClient(bridge.url);
    tools = (await client.listTools()).tools;
  });

  after(async () => {
    await client.close();
    await bridge.close();
  });

  test("advertises the full tool surface", () => {
    assert.deepEqual(
      tools.map((t) => t.name).sort(),
      [
        "complete_reminder",
        "create_calendar",
        "create_event",
        "create_reminder",
        "create_reminder_list",
        "delete_calendar",
        "delete_event",
        "delete_reminder",
        "delete_reminder_list",
        "get_event",
        "get_reminder",
        "list_calendars",
        "list_events",
        "list_reminder_lists",
        "list_reminders",
        "uncomplete_reminder",
        "update_calendar",
        "update_event",
        "update_reminder",
        "update_reminder_list",
      ]
    );
  });

  test("every tool has a description and an object input schema", () => {
    for (const tool of tools) {
      assert.ok(tool.description, `${tool.name} is missing a description`);
      assert.equal(tool.inputSchema.type, "object", `${tool.name} schema type`);
    }
  });

  test("required fields are preserved", () => {
    const required = (name) =>
      tools.find((t) => t.name === name).inputSchema.required ?? [];

    assert.deepEqual(required("create_reminder"), ["title"]);
    assert.deepEqual(required("create_event"), ["title", "startDate", "endDate"]);
    assert.deepEqual(required("list_events"), ["startDate", "endDate"]);
    assert.deepEqual(required("update_reminder"), ["id"]);
    // No-argument tools must not require anything.
    assert.deepEqual(required("list_reminder_lists"), []);
    assert.deepEqual(required("list_reminders"), []);
  });

  test("optional properties are declared but not required", () => {
    const schema = tools.find((t) => t.name === "create_reminder").inputSchema;

    assert.deepEqual(Object.keys(schema.properties).sort(), [
      "dueDate",
      "listId",
      "notes",
      "priority",
      "title",
      "url",
    ]);
    assert.equal(schema.properties.priority.type, "number");
    assert.equal(schema.properties.notes.type, "string");
    assert.ok(!schema.required.includes("notes"));
  });

  test("enum constraints survive schema generation", () => {
    const availability = tools.find((t) => t.name === "create_event").inputSchema
      .properties.availability;
    assert.deepEqual(availability.enum, ["busy", "free", "tentative", "unavailable"]);

    const span = tools.find((t) => t.name === "delete_event").inputSchema
      .properties.span;
    assert.deepEqual(span.enum, ["this", "future"]);
  });

  test("property descriptions are carried through", () => {
    const props = tools.find((t) => t.name === "list_reminders").inputSchema
      .properties;
    assert.equal(props.listId.description, "Filter by reminder list ID");
    assert.equal(props.completed.type, "boolean");
  });
});

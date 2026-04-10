#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const BASE_URL = process.env.APPLE_BRIDGE_URL || "http://127.0.0.1:23487";
const TOKEN = process.env.APPLE_BRIDGE_TOKEN;

if (!TOKEN) {
  console.error("APPLE_BRIDGE_TOKEN environment variable is required");
  process.exit(1);
}

// --- HTTP Client ---

async function api(method: string, path: string, body?: unknown): Promise<unknown> {
  const opts: RequestInit = {
    method,
    headers: {
      Authorization: `Bearer ${TOKEN}`,
      "Content-Type": "application/json",
    },
  };
  if (body) opts.body = JSON.stringify(body);

  const res = await fetch(`${BASE_URL}${path}`, opts);
  if (res.status === 204) return { success: true };
  const data = await res.json();
  if (!res.ok) throw new Error((data as { message?: string }).message || `HTTP ${res.status}`);
  return data;
}

function ok(data: unknown) {
  return { content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }] };
}

function err(e: unknown) {
  const msg = e instanceof Error ? e.message : String(e);
  return { content: [{ type: "text" as const, text: `Error: ${msg}` }], isError: true };
}

// --- MCP Server ---

const server = new McpServer(
  { name: "apple-bridge", version: "1.0.0" },
  { instructions: "Access Apple Reminders and Calendars via the apple-bridge API." }
);

// --- Reminder Lists ---

server.registerTool("list_reminder_lists", {
  description: "List all reminder lists",
  inputSchema: z.object({}),
}, async () => {
  try { return ok(await api("GET", "/reminder-lists")); }
  catch (e) { return err(e); }
});

server.registerTool("create_reminder_list", {
  description: "Create a new reminder list",
  inputSchema: z.object({
    title: z.string().describe("List name"),
    color: z.string().optional().describe("Hex color, e.g. #FF6B6B"),
  }),
}, async ({ title, color }) => {
  try { return ok(await api("POST", "/reminder-lists", { title, color })); }
  catch (e) { return err(e); }
});

server.registerTool("update_reminder_list", {
  description: "Update a reminder list",
  inputSchema: z.object({
    id: z.string().describe("List ID"),
    title: z.string().optional().describe("New title"),
    color: z.string().optional().describe("New hex color"),
  }),
}, async ({ id, title, color }) => {
  try { return ok(await api("PUT", `/reminder-lists/${id}`, { title, color })); }
  catch (e) { return err(e); }
});

server.registerTool("delete_reminder_list", {
  description: "Delete a reminder list and all its reminders",
  inputSchema: z.object({
    id: z.string().describe("List ID"),
  }),
}, async ({ id }) => {
  try { return ok(await api("DELETE", `/reminder-lists/${id}`)); }
  catch (e) { return err(e); }
});

// --- Reminders ---

server.registerTool("list_reminders", {
  description: "List reminders, optionally filtered by list, completion status, due date, or priority",
  inputSchema: z.object({
    listId: z.string().optional().describe("Filter by reminder list ID"),
    completed: z.boolean().optional().describe("Filter by completion status"),
    dueBefore: z.string().optional().describe("ISO 8601 date — only reminders due before this"),
    dueAfter: z.string().optional().describe("ISO 8601 date — only reminders due after this"),
    priority: z.number().optional().describe("Filter by priority (1=high, 5=medium, 9=low, 0=none)"),
  }),
}, async (params) => {
  try {
    const query = new URLSearchParams();
    if (params.listId) query.set("listId", params.listId);
    if (params.completed !== undefined) query.set("completed", String(params.completed));
    if (params.dueBefore) query.set("dueBefore", params.dueBefore);
    if (params.dueAfter) query.set("dueAfter", params.dueAfter);
    if (params.priority !== undefined) query.set("priority", String(params.priority));
    const qs = query.toString();
    return ok(await api("GET", `/reminders${qs ? `?${qs}` : ""}`));
  } catch (e) { return err(e); }
});

server.registerTool("get_reminder", {
  description: "Get a single reminder by ID",
  inputSchema: z.object({
    id: z.string().describe("Reminder ID"),
  }),
}, async ({ id }) => {
  try { return ok(await api("GET", `/reminders/${id}`)); }
  catch (e) { return err(e); }
});

server.registerTool("create_reminder", {
  description: "Create a new reminder",
  inputSchema: z.object({
    title: z.string().describe("Reminder title"),
    listId: z.string().optional().describe("Reminder list ID (uses default list if omitted)"),
    notes: z.string().optional().describe("Notes"),
    dueDate: z.string().optional().describe("Due date in ISO 8601 format"),
    priority: z.number().optional().describe("Priority: 0=none, 1=high, 5=medium, 9=low"),
    url: z.string().optional().describe("Associated URL"),
  }),
}, async (params) => {
  try { return ok(await api("POST", "/reminders", params)); }
  catch (e) { return err(e); }
});

server.registerTool("update_reminder", {
  description: "Update an existing reminder (partial update — only provided fields are changed)",
  inputSchema: z.object({
    id: z.string().describe("Reminder ID"),
    title: z.string().optional().describe("New title"),
    notes: z.string().optional().describe("New notes"),
    dueDate: z.string().optional().describe("New due date in ISO 8601 format"),
    priority: z.number().optional().describe("New priority: 0=none, 1=high, 5=medium, 9=low"),
    url: z.string().optional().describe("New URL"),
    listId: z.string().optional().describe("Move to a different list"),
  }),
}, async ({ id, ...data }) => {
  try { return ok(await api("PATCH", `/reminders/${id}`, data)); }
  catch (e) { return err(e); }
});

server.registerTool("delete_reminder", {
  description: "Delete a reminder",
  inputSchema: z.object({
    id: z.string().describe("Reminder ID"),
  }),
}, async ({ id }) => {
  try { return ok(await api("DELETE", `/reminders/${id}`)); }
  catch (e) { return err(e); }
});

server.registerTool("complete_reminder", {
  description: "Mark a reminder as complete",
  inputSchema: z.object({
    id: z.string().describe("Reminder ID"),
  }),
}, async ({ id }) => {
  try { return ok(await api("POST", `/reminders/${id}/complete`)); }
  catch (e) { return err(e); }
});

server.registerTool("uncomplete_reminder", {
  description: "Mark a reminder as incomplete",
  inputSchema: z.object({
    id: z.string().describe("Reminder ID"),
  }),
}, async ({ id }) => {
  try { return ok(await api("POST", `/reminders/${id}/uncomplete`)); }
  catch (e) { return err(e); }
});

// --- Calendars ---

server.registerTool("list_calendars", {
  description: "List all event calendars",
  inputSchema: z.object({}),
}, async () => {
  try { return ok(await api("GET", "/calendars")); }
  catch (e) { return err(e); }
});

server.registerTool("create_calendar", {
  description: "Create a new calendar",
  inputSchema: z.object({
    title: z.string().describe("Calendar name"),
    color: z.string().optional().describe("Hex color"),
  }),
}, async ({ title, color }) => {
  try { return ok(await api("POST", "/calendars", { title, color })); }
  catch (e) { return err(e); }
});

server.registerTool("update_calendar", {
  description: "Update a calendar",
  inputSchema: z.object({
    id: z.string().describe("Calendar ID"),
    title: z.string().optional().describe("New title"),
    color: z.string().optional().describe("New hex color"),
  }),
}, async ({ id, title, color }) => {
  try { return ok(await api("PUT", `/calendars/${id}`, { title, color })); }
  catch (e) { return err(e); }
});

server.registerTool("delete_calendar", {
  description: "Delete a calendar",
  inputSchema: z.object({
    id: z.string().describe("Calendar ID"),
  }),
}, async ({ id }) => {
  try { return ok(await api("DELETE", `/calendars/${id}`)); }
  catch (e) { return err(e); }
});

// --- Calendar Events ---

server.registerTool("list_events", {
  description: "List calendar events in a date range",
  inputSchema: z.object({
    startDate: z.string().describe("Start date in ISO 8601 format (required)"),
    endDate: z.string().describe("End date in ISO 8601 format (required)"),
    calendarId: z.string().optional().describe("Filter by calendar ID"),
  }),
}, async ({ startDate, endDate, calendarId }) => {
  try {
    const query = new URLSearchParams({ startDate, endDate });
    if (calendarId) query.set("calendarId", calendarId);
    return ok(await api("GET", `/events?${query}`));
  } catch (e) { return err(e); }
});

server.registerTool("get_event", {
  description: "Get a single calendar event by ID",
  inputSchema: z.object({
    id: z.string().describe("Event ID"),
  }),
}, async ({ id }) => {
  try { return ok(await api("GET", `/events/${id}`)); }
  catch (e) { return err(e); }
});

server.registerTool("create_event", {
  description: "Create a new calendar event",
  inputSchema: z.object({
    title: z.string().describe("Event title"),
    startDate: z.string().describe("Start date in ISO 8601 format"),
    endDate: z.string().describe("End date in ISO 8601 format"),
    calendarId: z.string().optional().describe("Calendar ID (uses default if omitted)"),
    notes: z.string().optional().describe("Notes"),
    location: z.string().optional().describe("Location text"),
    isAllDay: z.boolean().optional().describe("All-day event"),
    url: z.string().optional().describe("Associated URL"),
    availability: z.enum(["busy", "free", "tentative", "unavailable"]).optional().describe("Availability"),
  }),
}, async (params) => {
  try { return ok(await api("POST", "/events", params)); }
  catch (e) { return err(e); }
});

server.registerTool("update_event", {
  description: "Update a calendar event (partial update)",
  inputSchema: z.object({
    id: z.string().describe("Event ID"),
    title: z.string().optional().describe("New title"),
    startDate: z.string().optional().describe("New start date"),
    endDate: z.string().optional().describe("New end date"),
    calendarId: z.string().optional().describe("Move to a different calendar"),
    notes: z.string().optional().describe("New notes"),
    location: z.string().optional().describe("New location"),
    isAllDay: z.boolean().optional().describe("All-day event"),
    url: z.string().optional().describe("New URL"),
    availability: z.enum(["busy", "free", "tentative", "unavailable"]).optional().describe("New availability"),
  }),
}, async ({ id, ...data }) => {
  try { return ok(await api("PATCH", `/events/${id}`, data)); }
  catch (e) { return err(e); }
});

server.registerTool("delete_event", {
  description: "Delete a calendar event",
  inputSchema: z.object({
    id: z.string().describe("Event ID"),
    span: z.enum(["this", "future"]).optional().describe("For recurring events: 'this' (default) or 'future'"),
  }),
}, async ({ id, span }) => {
  try {
    const query = span ? `?span=${span}` : "";
    return ok(await api("DELETE", `/events/${id}${query}`));
  } catch (e) { return err(e); }
});

// --- Start ---

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("apple-bridge MCP server running on stdio");
}

main().catch((e) => {
  console.error("Fatal error:", e);
  process.exit(1);
});

# apple-bridge

A macOS tool that exposes Apple Reminders and Calendars via a local HTTP API, web UI, and MCP server — using EventKit. Zero third-party dependencies for the core server.

## Features

- **HTTP API** — REST endpoints for Reminders, Reminder Lists, Calendar Events, and Calendars
- **Web UI** — Apple Reminders-style web app at `/app` for managing reminders in the browser
- **MCP Server** — Model Context Protocol server for AI agent integration (Claude Code, OpenClaw, etc.)
- **API Docs** — Interactive Swagger UI at `/docs`
- **API Key Auth** — Read/write and read-only keys with SHA-256 hashing
- **Status Bar** — Optional macOS menu bar icon
- **launchd** — Run as a persistent background service

## Requirements

- macOS 14 (Sonoma) or later
- Swift 6.0+ / Xcode 16+
- Node.js 18+ (for MCP server only)

## Build & Install

```bash
task release    # build release binary
task sign       # ad-hoc sign (no developer account needed, no expiry)
task install    # copy to /usr/local/bin
```

## First-Time Setup

### 1. Create an API key

```bash
apple-bridge keys create --label "my-key"
apple-bridge keys create --label "viewer" --readonly   # read-only key
```

Save the key that's printed — it can't be retrieved again.

### 2. Grant EventKit permissions

Run the server once interactively:

```bash
apple-bridge serve
```

macOS will prompt you to grant access to Reminders and Calendars. Approve both.

Note: The TCC permission prompt comes from your terminal app, not the binary itself. If it doesn't appear, try resetting permissions first:

```bash
tccutil reset Reminders
tccutil reset Calendar
```

Then run the server again.

## Usage

### Start the server

```bash
apple-bridge serve                              # defaults: 127.0.0.1:23487
apple-bridge serve --host 0.0.0.0 --port 8080   # custom bind
apple-bridge serve --status-bar                  # show menu bar icon
```

### Run in the background

```bash
apple-bridge serve --status-bar &
disown
```

### Run as a launchd service (recommended)

For a persistent background service that starts on login and restarts on crash:

```bash
task install          # builds release, signs, copies to /usr/local/bin
task setup-launchd    # installs and starts the launchd agent
```

This is the recommended approach for headless servers (e.g. a Mac Mini). No terminal or GUI needed.

```bash
task remove-launchd   # stop and uninstall
```

Edit `com.apple-bridge.agent.plist` to change the host/port before installing. Logs go to `/tmp/apple-bridge.{stdout,stderr}.log`.

### Manage API keys

```bash
apple-bridge keys create [--label <name>] [--readonly]
apple-bridge keys list
apple-bridge keys revoke <id>
```

Keys can be **read/write** (default) or **read-only** (`--readonly`). Read-only keys can only make GET requests — write operations return 403.

### Web UI

Open [http://127.0.0.1:23487/app](http://127.0.0.1:23487/app) in your browser. Enter your API token to connect. The web UI supports:

- Viewing and switching between reminder lists
- Creating, editing, completing, and deleting reminders
- Due dates, priorities, notes, and URLs
- Search across reminders
- Creating, editing, and deleting reminder lists

Read-only tokens hide all write UI elements.

### API Docs (Swagger UI)

Open [http://127.0.0.1:23487/docs](http://127.0.0.1:23487/docs) for interactive API documentation. The OpenAPI spec is also available at `/openapi.yaml` and in `docs/openapi.yaml`.

## MCP Server

The MCP server allows AI agents to manage your Reminders and Calendars as tools.

### Install from npm

```bash
npm install -g @evoio/apple-bridge-mcp
```

Or use directly with npx (no install needed).

### Register with Claude Code

```bash
claude mcp add apple-bridge \
  -e APPLE_BRIDGE_TOKEN=mb_YOUR_KEY \
  -- npx @evoio/apple-bridge-mcp
```

### Build from source

```bash
task mcp:build   # install deps and compile TypeScript
```

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `APPLE_BRIDGE_TOKEN` | (required) | API key for authentication |
| `APPLE_BRIDGE_URL` | `http://127.0.0.1:23487` | API server URL |

### Available tools

| Tool | Description |
|------|-------------|
| `list_reminder_lists` | List all reminder lists |
| `create_reminder_list` | Create a reminder list |
| `update_reminder_list` | Update a reminder list |
| `delete_reminder_list` | Delete a reminder list |
| `list_reminders` | List reminders (with filters) |
| `get_reminder` | Get a single reminder |
| `create_reminder` | Create a reminder |
| `update_reminder` | Update a reminder |
| `delete_reminder` | Delete a reminder |
| `complete_reminder` | Mark reminder complete |
| `uncomplete_reminder` | Mark reminder incomplete |
| `list_calendars` | List all calendars |
| `create_calendar` | Create a calendar |
| `update_calendar` | Update a calendar |
| `delete_calendar` | Delete a calendar |
| `list_events` | List events in a date range |
| `get_event` | Get a single event |
| `create_event` | Create an event |
| `update_event` | Update an event |
| `delete_event` | Delete an event |

## API Reference

All endpoints require `Authorization: Bearer <key>` except `GET /health`.

All dates are ISO 8601 format. All responses are JSON. Reminders default to showing only incomplete — pass `completed=all` to include completed.

### Health

```
GET /health
```

Returns `{"status": "ok", "version": "1.0.0"}`. No authentication required.

### Auth

```
GET /auth/me
```

Returns `{"permission": "readwrite"}` or `{"permission": "read"}`.

---

### Reminders

#### List reminders

```
GET /reminders
```

Query parameters (all optional):
- `listId` — filter by reminder list
- `completed` — `false` (default), `true`, or `all`
- `dueBefore` — ISO 8601 date
- `dueAfter` — ISO 8601 date
- `priority` — integer (0 = none, 1 = high, 5 = medium, 9 = low)

#### Get / Create / Update / Delete

```
GET    /reminders/:id
POST   /reminders              # body: {title, notes?, listId?, dueDate?, priority?, url?, alarms?, recurrenceRules?, location?}
PUT    /reminders/:id          # full update — missing fields reset to defaults
PATCH  /reminders/:id          # partial update — only provided fields change
DELETE /reminders/:id          # returns 204
```

#### Complete / Uncomplete

```
POST /reminders/:id/complete
POST /reminders/:id/uncomplete
```

---

### Reminder Lists

```
GET    /reminder-lists
GET    /reminder-lists/:id
POST   /reminder-lists         # body: {title, color?}
PUT    /reminder-lists/:id
DELETE /reminder-lists/:id
```

---

### Calendar Events

#### List events

```
GET /events?startDate=2026-04-01T00:00:00Z&endDate=2026-04-30T23:59:59Z
```

Required: `startDate`, `endDate`. Optional: `calendarId`.

#### Get / Create / Update / Delete

```
GET    /events/:id
POST   /events                 # body: {title, startDate, endDate, calendarId?, notes?, location?, isAllDay?, url?, availability?, alarms?, recurrenceRules?}
PUT    /events/:id
PATCH  /events/:id
DELETE /events/:id?span=this   # span: "this" (default) or "future" for recurring
```

---

### Calendars

```
GET    /calendars
GET    /calendars/:id
POST   /calendars              # body: {title, color?}
PUT    /calendars/:id
DELETE /calendars/:id
```

---

### Response format

List endpoints return `{"items": [...], "count": N}`.

Errors return `{"error": "snake_case_code", "message": "Human readable"}`.

### HTTP status codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 201 | Created |
| 204 | Deleted (no body) |
| 400 | Bad request |
| 401 | Unauthorized |
| 403 | Forbidden (read-only key) |
| 404 | Not found |
| 405 | Method not allowed |
| 413 | Request body too large (>1MB) |
| 500 | Server error |

## Running Tests

```bash
task test
```

Unit tests cover the HTTP parser, router, API key store, Codable models, and CLI parser.

## Architecture

- **HTTP server**: Apple `Network` framework (`NWListener`), zero third-party dependencies
- **EventKit**: Shared `EKEventStore` with synchronous service layer
- **Auth**: Bearer token API keys with read/write and read-only permissions, SHA-256 hashed, stored in `~/.config/apple-bridge/keys.json`
- **Web UI**: Single HTML page with embedded CSS/JS served at `/app`
- **MCP server**: TypeScript, wraps the HTTP API as MCP tools over stdio
- **Dual mode**: Headless daemon (default) or menu bar icon (`--status-bar`)

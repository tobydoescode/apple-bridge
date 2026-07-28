# @evoio/apple-bridge-mcp

MCP server for managing Apple Reminders and Calendars. Wraps the [apple-bridge](https://github.com/tobydoescode/apple-bridge) HTTP API as Model Context Protocol tools for AI agents.

## Prerequisites

- [apple-bridge](https://github.com/tobydoescode/apple-bridge) running on the target macOS machine
- An API key created via `apple-bridge keys create`

## Usage with Claude Code

```bash
claude mcp add apple-bridge \
  -e APPLE_BRIDGE_TOKEN=mb_YOUR_KEY \
  -- npx @evoio/apple-bridge-mcp
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `APPLE_BRIDGE_TOKEN` | (required) | API key for authentication |
| `APPLE_BRIDGE_URL` | `http://127.0.0.1:23487` | API server URL |

## Available Tools

### Reminders
- `list_reminders` — List reminders with filters (list, completion status, due date, priority)
- `get_reminder` — Get a single reminder
- `create_reminder` — Create a reminder
- `update_reminder` — Update a reminder
- `delete_reminder` — Delete a reminder
- `complete_reminder` — Mark complete
- `uncomplete_reminder` — Mark incomplete

### Reminder Lists
- `list_reminder_lists` — List all reminder lists
- `create_reminder_list` — Create a list
- `update_reminder_list` — Update a list
- `delete_reminder_list` — Delete a list

### Calendar Events
- `list_events` — List events in a date range
- `get_event` — Get a single event
- `create_event` — Create an event
- `update_event` — Update an event
- `delete_event` — Delete an event

### Calendars
- `list_calendars` — List all calendars
- `create_calendar` — Create a calendar
- `update_calendar` — Update a calendar
- `delete_calendar` — Delete a calendar

## License

MIT

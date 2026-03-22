---
name: apple-calendar
description: Read, create, update, and delete Apple Calendar events on the local macOS machine. Use this skill when the user wants to inspect calendars, list events in a bounded time window, or modify Apple Calendar items directly from OpenClaw on a Mac.
---

# Apple Calendar

Use this skill for local Apple Calendar work on macOS. It is backed by a native Swift CLI that talks to `EventKit`, so responses are structured JSON and changes apply directly to Calendar data on this Mac.

## First Run

Run `./scripts/apple-calendar authorize` before the first read or write. macOS will prompt for Calendar access. If OpenClaw runs under a different host app, grant Calendar access to that host as well.

## Workflow

1. Use absolute timestamps, preferably ISO 8601 with a timezone offset.
2. Run `./scripts/apple-calendar list-calendars` to discover the target calendar.
3. For reads, use `list-events` with a bounded `--start` and `--end`.
4. For updates or deletes, reuse the returned event `id`.
5. For destructive actions, only run them when the user clearly asked for the change.

## Commands

```bash
./scripts/apple-calendar authorize
./scripts/apple-calendar list-calendars
./scripts/apple-calendar list-events --start 2026-03-22T00:00:00-04:00 --end 2026-03-23T00:00:00-04:00 --calendar Work
./scripts/apple-calendar get-event --id EVENT_ID
./scripts/apple-calendar create-event --calendar Work --title "Planning" --start 2026-03-22T15:00:00-04:00 --end 2026-03-22T15:30:00-04:00 --location "Zoom"
./scripts/apple-calendar update-event --id EVENT_ID --title "Updated title" --notes "Revised agenda" --span this
./scripts/apple-calendar delete-event --id EVENT_ID --span this
```

## Notes

- `--calendar` accepts either a calendar title or a calendar identifier. Exact matches are preferred.
- `list-events` supports `--query` and `--limit` for filtering.
- `update-event` treats `--location ""`, `--notes ""`, and `--url ""` as clear operations.
- `--span future` applies recurring-event updates or deletes to future items in the series. The default is `this`.
- All commands print JSON to stdout and return a non-zero exit code on failure.

# Apple Calendar OpenClaw Skill

An OpenClaw skill for reading, creating, updating, and deleting Apple Calendar events directly on macOS.

This repo includes:

- A skill definition in `SKILL.md`
- OpenClaw UI metadata in `agents/openai.yaml`
- A native Swift CLI built on `EventKit`
- Shell scripts for local invocation and installation

## Requirements

- macOS
- Xcode Command Line Tools or Xcode with `swiftc`
- Calendar access granted to the app or terminal host running the commands

## Commands

```bash
./scripts/apple-calendar list-calendars
./scripts/apple-calendar list-events --start 2026-03-22T00:00:00-04:00 --end 2026-03-23T00:00:00-04:00
./scripts/apple-calendar create-event --calendar Work --title "Planning" --start 2026-03-22T15:00:00-04:00 --end 2026-03-22T15:30:00-04:00
./scripts/apple-calendar update-event --id EVENT_ID --title "Updated title"
./scripts/apple-calendar delete-event --id EVENT_ID
```

The script compiles the Swift CLI on demand into `.build/local/`, which is ignored by git.

## Install Into OpenClaw

Symlink this repo into your OpenClaw skills directory:

```bash
./scripts/install-skill-link /path/to/openclaw/skills
```

## License

MIT. See `LICENSE`.

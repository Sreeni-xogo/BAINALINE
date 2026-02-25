# /checkpoint — Session Memory Capture

> Save a 1-line summary of this session to Memory/_sessions.md.
> Use at natural pause points when not inside a BRAIN session.

## When to use
- Quick fixes, debugging sessions, exploration work
- Any time you want to preserve context without a full BRAIN flow

## Steps

1. Generate a 3-5 bullet summary of what was done/decided this session
2. Condense to 1 line
3. Show user:
   > "Save to memory? → '{summary}'"
4. If yes:
   a. Read `Memory/_sessions.md` (or create if missing)
   b. Append under today's `## YYYY-MM-DD` header:
      `- {HH:MM} | Checkpoint | {ProjectName} — {summary}`
   c. If `Memory/.local/_index.md` exists (or create it):
      Append same entry with `→ {current-session-uuid}.jsonl`
5. If no → skip silently

## Memory/_sessions.md format

```
# Session Log

## YYYY-MM-DD
- HH:MM | EventType | ProjectName — summary
```

## Notes
- Append-only — never edit existing entries
- One line per event
- EventTypes: BRAIN Refine, BRAIN Arrange, Intent Done, Dissolved, Checkpoint, Session End

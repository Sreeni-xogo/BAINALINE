# Project Recap

Summarize the current project state to re-establish context.

## Instructions

Run these checks and present a concise summary:

0. **Recent Session Memory (always first)**
   - Read `Memory/_sessions.md` — last 10 entries (or all if file is small)
   - If `Memory/.local/_index.md` exists, note available JSONL files for deep reads
   - Summarise: last event type, feature worked on, outcome
   - If nothing found, note "No session memory yet" and continue

1. **Git State**
   - Current branch
   - Clean or uncommitted changes?
   - Last 3 commits (oneline)

2. **Project Context**
   - Read `CONTEXT.md` for project structure and constraints
   - Note the build/test commands

3. **Active Intents**
   - Check `Intents/` for any in-progress work
   - Find the most recently modified intent folder
   - If a `Status.md` exists, report current intent status

4. **Dissolved Intent Memory**
   - Check if `Memory/` folder exists
   - If yes, read `Memory/{ProjectName}.md` and note any relevant past outcomes or follow-ups
   - If empty or missing, skip silently

5. **Open Questions**
   - Any blockers or decisions noted in intent files or Memory?

## Output Format

```
## Project Recap

**Recent Sessions:** {summary of last session, or "No session memory yet"}

**Branch:** {branch} ({clean/uncommitted changes})
**Recent commits:**
- {hash} {message}
- {hash} {message}
- {hash} {message}

**Project:** {brief description from CONTEXT.md}
**Build:** `{command}` | **Test:** `{command}`

**Active Work:**
- {Intent folder}: {current intent or "no intents started"}
- Status: {from Status.md or "unknown"}

**Past Work (dissolved):**
- {summary from Memory/{Project}.md, or "none yet"}

**Notes:**
- {any blockers, decisions, or open questions from intents or Memory}
```

---

> **Usage notes:** Run when starting a new session, after context gets long, before making significant changes, or when you've lost track of where things stand.

$ARGUMENTS

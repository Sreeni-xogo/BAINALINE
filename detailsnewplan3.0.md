# Details & New Plan 3.0 — Session Memory Deep Dive
**Date:** 2026-02-24
**Project:** D:\XOGO\BAINALINE
**Purpose:** Document findings on how Aline works, how Claude manages sessions, and what the real memory problem is.

---

## Part 1 — How Claude Session Files Work

### Where they live
```
~/.claude/projects/{project-slug}/
  35e868af-7326-437c-849d-d12f1573d838.jsonl  ← old session
  12cf92c4-bce8-4728-b4db-519a9c165253.jsonl  ← old session
  ...
  609f1085-bef9-4ea9-827b-3e587cdd2e49.jsonl  ← current session
```

Each `.jsonl` file = **one Claude conversation**. New conversation = new UUID filename.

### What is inside a JSONL file

Every line is a JSON object representing one event. Types include:

| Entry type | What it contains |
|---|---|
| `user` | Your message, cwd, session ID, git branch, timestamp |
| `assistant` | Claude's response, model used, token counts, thinking blocks |
| `tool_use` | Every tool Claude called (Read, Bash, Edit, etc.) |
| `tool_result` | The output of every tool call |
| `file-history-snapshot` | Snapshot of tracked file backups |
| `summary` | Compact summary (written when /compact runs) |

### Example of what one line looks like (simplified)
```json
{
  "type": "user",
  "message": { "role": "user", "content": "read the @BRAIN-ALINE-STRATEGY.md and start the work" },
  "sessionId": "609f1085-bef9-4ea9-827b-3e587cdd2e49",
  "cwd": "D:\\XOGO\\BAINALINE",
  "gitBranch": "main",
  "timestamp": "2026-02-23T17:09:24.021Z"
}
```

Every thinking block, every tool result, every token count — all recorded permanently on disk.

---

## Part 2 — How the /compact Command Works

### What triggers it
- Manual: user types `/compact`
- Auto: Claude Code detects the context window is filling up

### What it does step by step

```
Long session in progress → 609f1085...jsonl growing large
  ↓
/compact triggered
  ↓
Claude reads ALL turns in the current session
  ↓
Generates a compressed summary (~500–1000 tokens)
  ↓
Appends a new "summary" entry to the SAME JSONL file
  ↓
Claude's active context is replaced by the summary
  ↓
Session continues — new turns appended after the summary
  ↓
Old turns still exist in the file on disk
  ↓
Claude no longer reads the old turns — only works from summary forward
```

### What the compact summary captures (and loses)

| What is kept | What is lost |
|---|---|
| High-level facts: what was built | WHY decisions were made |
| File names and commands run | Rejected alternatives |
| Final outcomes | Reasoning chains and thinking blocks |
| Current state | Tool output details (file contents, diffs) |
| Key errors encountered | Nuance, context, pivots made mid-session |

**The summary is optimised for token compression, not future session resumption.**

### What /compact does NOT do
- Does NOT create a new JSONL file
- Does NOT delete the old turns from disk
- Does NOT carry context forward to a future new session
- Does NOT read previous sessions' JSONL files

---

## Part 3 — The Session Memory Problem

### The core gap

```
Session A: 609f1085...jsonl
  You and Claude design BRAIN+Aline for 4 hours.
  All decisions, reasoning, alternatives — recorded in full.
  Session ends.
  ↓
Session B: a73bb289...jsonl (new conversation next day)
  Claude opens a fresh JSONL.
  Has ZERO awareness of Session A.
  You must re-explain everything from scratch.
  ↓
Session C: 3b449373...jsonl (one week later)
  Claude opens another fresh JSONL.
  Has ZERO awareness of Sessions A or B.
  13 JSONL files on disk = 13 sessions of context = all ignored.
```

**The data exists. It is sitting on disk. Claude simply never reads previous session files.**

### Why it happens

Claude Code only loads the CURRENT session JSONL into context at startup. There is no mechanism to auto-read prior sessions. Each session is a clean slate by design (privacy, token cost, context limits).

### Token cost of the problem

| Scenario | Without session memory | With session memory |
|---|---|---|
| Resume work next day | ~2000 tokens re-explaining context | ~200 tokens reading a summary |
| Teammate picks up project | Full re-explanation + reading all files | Read Memory/ + prior session summary |
| After compact mid-session | Lose all reasoning from first half | Lose all reasoning from first half |
| New session after long break | Complete amnesia | Structured recall from Memory/ |

---

## Part 4 — How Aline Actually Works (Full Reverse Engineering)

### The marketing vs the reality

**Marketing says:** "Auto-commits your progress to git, persistent AI memory layer"

**Reality:** Aline is a **local SQLite database** + **daemon system** that reads Claude's JSONL files and summarises them.

### The real architecture

```
Claude session runs (you type, Claude responds)
  ↓
Stop hook fires after each Claude turn
  ↓
stop_hook.py reads: session_id + transcript_path from stdin
  ↓
Enqueues a job into local SQLite: ~/.aline/db/aline.db
  ↓
Background watcher_daemon.py detects the queued job
  ↓
Background worker_daemon.py processes the job:
  - Reads the JSONL transcript file
  - Calls an LLM to generate a title + description
  - Stores the summarised turn in SQLite
  ↓
MCP server = query interface to that SQLite DB
  ↓
"use aline — what was I last working on?" =
  MCP tool queries SQLite → returns LLM-generated summaries to Claude
```

### What Aline stores

- NOT in git commits (misleading marketing)
- In `~/.aline/db/aline.db` — local SQLite on your machine
- Per session, per turn summaries generated by an LLM call
- Context entries linking sessions to workspaces (`~/.aline/load.json`)

### What "use aline — commit" actually does

When Claude calls `use aline — commit: {message}`, the MCP tool:
1. Creates a new entry in the SQLite DB tagged with that message
2. Does NOT make a git commit
3. Is queryable in future sessions via the MCP

### Why it fails on Windows

| Issue | Root cause |
|---|---|
| `aline-mcp` not found | npm wrapper calls `uvx aline-mcp` but executable is `aline.exe` |
| `uvx.cmd` not found | uv installs `uvx.exe` but no `.cmd` shim — had to manually create |
| Unicode errors in CLI | Aline uses `rich` library with box-drawing Unicode chars, Windows cp1252 can't encode them |
| Daemon issues | Architecture designed for Mac/Linux with tmux — not Windows native |
| MCP server broken | `bin/aline-mcp.js` (npm) calls a non-existent Python entry point |

### What the `aline doctor` command revealed

When run with `PYTHONUTF8=1`, `aline doctor` auto-updated:
- Claude Code hooks: `Stop`, `UserPromptSubmit`, `PermissionRequest`
- Global Codex config
- 3 skill files
- 2 instruction blocks

This means Aline installs its own hooks into your global Claude config — **bypassing the project-level hooks we set up**. This is another reliability concern.

---

## Part 5 — The Key Insight

### Aline's actual value

Aline's real job is simple:
1. Read Claude's JSONL transcripts automatically
2. Summarise them with an LLM
3. Make those summaries queryable in future sessions via MCP

### We already have a better version

| Aline component | Our BRAIN+Aline equivalent |
|---|---|
| SQLite DB (memory store) | `Memory/ProjectName.md` — human-readable, in git |
| LLM summarisation | Claude summarises at BRAIN phase gates — higher quality |
| MCP query interface | `/recap` command reads Memory/ files directly |
| Stop hook capture | CLAUDE.md natural pause point rule |
| Per-session history | `Memory/_sessions.md` (proposed — not yet built) |

### Why ours is better

- No external dependencies
- No daemons
- No MCP server to break
- Works on Windows
- Memory is in git — version controlled, shareable, human-readable
- BRAIN phase gates produce HIGH quality summaries (structured, intentional)
- Aline summaries are generic LLM outputs from raw transcripts (noisy)

---

## Part 6 — What Still Needs to Be Built (Gap)

### The one remaining gap

Non-BRAIN sessions (quick fixes, debugging, exploration) have no memory capture mechanism now that Aline is removed.

### Proposed solution: Native /checkpoint command

```
Session reaches natural pause point
  ↓
User types /checkpoint (or Claude detects pause point via CLAUDE.md rule)
  ↓
Claude summarises the session: 3-5 bullets of what was done/decided
  ↓
Shows user: "Want to save this to Memory/_sessions.md?"
  ↓
Yes → appends dated entry to Memory/_sessions.md
No → skip
```

### Memory/_sessions.md format

```md
# Session Log

## 2026-02-24 — BAINALINE
- Reversed-engineered Aline: local SQLite, not git commits
- Discovered JSONL files contain full session history on disk
- Confirmed /compact stays in same file, no new JSONL created
- Decision: remove Aline dependency, build native Memory/ approach

## 2026-02-23 — BAINALINE
- Designed BRAIN+Aline integration strategy
- Chose per-intent dissolution (Option C)
- Built /dissolve with two-level flow
```

### How /recap uses it

```
/recap invoked
  ↓
1. Read Memory/_sessions.md (recent session log)        ← replaces Aline recall
2. Read Memory/{ProjectName}.md (dissolved intent log)  ← already built
3. Read Intents/{Active}/Status.md                      ← already built
4. Git log                                              ← already built
  ↓
Full picture: recent sessions + feature history + active work
```

---

## Part 7 — Action Items (BRAIN 3.0)

| # | Action | Priority |
|---|---|---|
| 1 | Remove all `use aline` calls from `brain.md` — replace with `Memory/` writes | High |
| 2 | Create `/checkpoint` command | High |
| 3 | Update `recap.md` — replace Aline recall step with `Memory/_sessions.md` read | High |
| 4 | Update `CLAUDE.md` — remove Aline references, native memory only | High |
| 5 | Remove UserPromptSubmit hook (Aline-specific) | Medium |
| 6 | Test full flow on `playwrightAutomationV3` | High |

---

> **Bottom line:** Aline is a clever tool but over-engineered for what we need and unreliable on Windows.
> Our `Memory/` + BRAIN phase gates approach achieves the same goal with zero dependencies,
> full git versioning, and human-readable output.

---

## Part 8 — BRAIN 3.0 Final Design

### Core principle

Replace every `use aline — commit/recall` call with direct writes/reads to markdown files.
No MCP. No daemon. No external tool. Claude manages memory itself.

---

### The two-layer memory structure

```
Memory/                          ← committed to git (shared with team)
  _sessions.md                   ← shared 1-line session log (summaries only)
  FeatureA.md                    ← dissolved intent history (full context)
  FeatureB.md                    ← dissolved intent history
  .local/                        ← gitignored (machine-local only)
    _index.md                    ← personal JSONL pointers for on-demand deep reads
```

`.gitignore` entry required:
```
Memory/.local/
```

---

### Why two layers?

JSONL files (`~/.claude/projects/.../*.jsonl`) are **personal and machine-local** — they never go into git and are never shared. So JSONL pointers are only useful on the machine that created them.

| Layer | File | In git | Who sees it |
|---|---|---|---|
| Shared summaries | `Memory/_sessions.md` | ✅ Yes | All devs |
| Shared feature history | `Memory/{Feature}.md` | ✅ Yes | All devs |
| Local JSONL index | `Memory/.local/_index.md` | ❌ gitignored | Machine owner only |

---

### `Memory/_sessions.md` — shared session log (git)

One line per significant session event. Summaries only — no JSONL pointers.

```md
# Session Log

## 2026-02-24
- 17:09 | BRAIN Refine | BrainAline — "integrate Aline phase gates into BRAIN flow"
- 18:32 | BRAIN Arrange | BrainAline — "intents 01–07 approved"
- 19:45 | Intent 01 done | BrainAline — "brain.md phase gates added"
- 20:10 | Session end | BrainAline — status: Active

## 2026-02-25
- 09:15 | Checkpoint | playwrightAutomationV3 — "fixed uvx.cmd shim on Windows"
```

---

### `Memory/.local/_index.md` — personal JSONL index (gitignored)

Same entries as `_sessions.md` but with JSONL filename appended. Used for on-demand deep reads.

```md
# Local JSONL Index

## 2026-02-24
- 17:09 | BRAIN Refine | BrainAline → 609f1085.jsonl
- 18:32 | BRAIN Arrange | BrainAline → 609f1085.jsonl
- 19:45 | Intent 01 done | BrainAline → 609f1085.jsonl
- 20:10 | Session end | BrainAline → 609f1085.jsonl
```

---

### How Claude reads memory — lazy loading

```
/recap or /brain invoked
  ↓
Step 1: Read Memory/_sessions.md (tiny — always)
        → 1-line summaries of recent sessions
        → Is this enough context to continue?
          → Yes → proceed, never touch JSONL
          → No (blocker unclear, user asks "why did we...") →
              Check Memory/.local/_index.md for JSONL pointer
              Read only the relevant section of that JSONL
              Extract the specific context needed
```

**JSONL files are never read automatically — only on-demand when the summary is insufficient.**

---

### What each type of user gets

| User | What they can access | Context quality |
|---|---|---|
| Original dev (same machine) | `_sessions.md` + `_index.md` → JSONL deep reads | Full — complete session history |
| Original dev (new machine) | `_sessions.md` + `{Feature}.md` from git | Good — summaries + feature history |
| New teammate (clone) | `_sessions.md` + `{Feature}.md` from git | Good — summaries + feature history |
| Long-running project, 10 devs | Each dev appends to shared `_sessions.md` | Full team history builds over time |

---

### How BRAIN 3.0 session flows

#### BRAIN session
```
/brain "FeatureName" invoked
  ↓
Read Memory/_sessions.md (last 5 entries) + Memory/FeatureName.md if exists
Summarise what was found to user: "Last time: intent 02 was blocked on X"
  ↓
Begin → Refine → Arrange → Iterate → Next (unchanged)
  ↓
After Refine locked:
  Append to Memory/_sessions.md + Memory/.local/_index.md:
  "BRAIN Refine | FeatureName — {goal summary}"
  ↓
After Arrange approved:
  Append to both:
  "BRAIN Arrange | FeatureName — intents 01–N created"
  ↓
Each intent Done:
  Append to both:
  "Intent N done | FeatureName — {outcome}"
  → dissolution prompt follows (unchanged)
  ↓
Session end (Next phase):
  Append to both:
  "Session end | FeatureName — status: Active/Paused/Complete"
```

#### Non-BRAIN session
```
Any session (quick fix, debug, exploration)
  ↓
Work happens...
  ↓
Natural pause point (CLAUDE.md rule) OR /checkpoint command
  ↓
Claude generates 3-5 bullet summary
  ↓
Asks: "Save to memory? → {summary}"
  ↓
Yes → append 1-line entry to Memory/_sessions.md + Memory/.local/_index.md
No → skip
```

---

### What changes from BRAIN 2.0 → BRAIN 3.0

| Component | BRAIN 2.0 | BRAIN 3.0 |
|---|---|---|
| Session recall | `use aline — recall` (MCP) | Read `Memory/_sessions.md` directly |
| Phase gate writes | `use aline — commit: ...` (MCP) | Append to `Memory/_sessions.md` + `_index.md` |
| Deep context | Not available | Read JSONL on-demand via `_index.md` |
| Non-BRAIN capture | UserPromptSubmit hook → Aline | `/checkpoint` → `Memory/_sessions.md` |
| Multi-user support | ❌ SQLite local only | ✅ Shared via git (`_sessions.md`) |
| Works on Windows | ❌ Unreliable | ✅ Always |
| Memory in git | ❌ Local SQLite only | ✅ `_sessions.md` + `{Feature}.md` |
| External dependency | Aline MCP + daemons | None |

---

### What stays the same

- `/dissolve` two-level flow — unchanged
- `Memory/{Feature}.md` dissolution format — unchanged
- BRAIN phases (Begin → Refine → Arrange → Iterate → Next) — unchanged
- Dissolution prompt after each intent Done — unchanged
- `/recap` structure — updated step 0 only (read `_sessions.md` instead of Aline recall)

---

### Updated action items for implementation

| # | Action | File |
|---|---|---|
| 1 | Replace all `use aline` calls with Memory writes | `.claude/commands/brain.md` |
| 2 | Create `/checkpoint` command | `.claude/commands/checkpoint.md` |
| 3 | Update `/recap` step 0 — read `_sessions.md` + lazy JSONL | `.claude/commands/recap.md` |
| 4 | Update `CLAUDE.md` — remove Aline refs, native memory rule | `CLAUDE.md` |
| 5 | Remove UserPromptSubmit hook | `.claude/settings.json` |
| 6 | Add `Memory/.local/` to `.gitignore` | `.gitignore` |
| 7 | Update `detailsnewplan3.0.md` → PLAN2026-02-24.md | `PLAN2026-02-24.md` |
| 8 | Test full flow on `playwrightAutomationV3` | — |

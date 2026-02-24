# BRAIN + Aline: The Complete Context Strategy

> Author: Sreeni · Created: 2026-02-23
> Purpose: Document the rationale, limitations, and integration strategy for combining the BRAIN method with Aline persistent memory.

---

## Table of Contents

1. [What is the BRAIN Method?](#1-what-is-the-brain-method)
2. [How Intents Work in This Project](#2-how-intents-work-in-this-project)
3. [The Disadvantages of Intents Alone](#3-the-disadvantages-of-intents-alone)
4. [What is Aline?](#4-what-is-aline)
5. [The Disadvantages of Aline Alone](#5-the-disadvantages-of-aline-alone)
6. [Why They Are a Perfect Complement](#6-why-they-are-a-perfect-complement)
7. [Recommended Integration Architecture](#7-recommended-integration-architecture)
8. [Implementation Plan](#8-implementation-plan)

---

## 1. What is the BRAIN Method?

BRAIN is a structured, human-AI collaborative planning framework. It breaks any idea or feature into a disciplined 5-phase workflow before a single line of code is written.

### The 5 Phases

| Phase | Owner | Time Limit | What Happens |
|---|---|---|---|
| **B**egin | 100% Human | ≤ 3 min | Raw brain dump — no AI analysis, no suggestions. Pure capture. |
| **R**efine | 90% Human | ≤ 15 min | AI asks 3–5 clarifying questions to scope the idea precisely. |
| **A**rrange | 90% AI | — | AI proposes a breakdown of 5–10 intents (each ≤ 2 hours). Provisional until human approves. |
| **I**terate | 90% AI | — | Execute intents one at a time. Log outcomes and blockers. Commit at each boundary. |
| **N**ext | 100% Human | — | Decide: continue, pause, switch project, or add to backlog. |

### Core Design Principles

- **No intent is executed without human approval** at the Arrange stage
- **Git commits are mandatory** at each intent boundary (clean rollback points)
- **One intent = one objective** — no scope creep within a single intent
- **Each intent has a Definition of Done** — no ambiguity about completion
- **Claude may update Status; Human owns Actual time** — clear ownership boundary

### What BRAIN Produces

```
Intents/
  {FeatureName}/
    CONTEXT.md      ← Goal, scope, constraints, DoD (set during Begin + Refine)
    Status.md       ← Progress table across all intents
    01.IntentName.md
    02.IntentName.md
    ...
```

**Example from this project:**
```
Intents/ProjectScaffold/
  CONTEXT.md        ← Playwright scaffold scope, environments, constraints
  Status.md         ← All 5 intents tracked (all Done)
  01.FolderStructure.md
  02.PlaywrightConfig.md
  03.EnvAndTsConfig.md
  04.BasePageClass.md
  05.PackageScripts.md
```

---

## 2. How Intents Work in This Project

Intents are invoked via the `/brain` skill in Claude Code:

```
/brain "My Feature Name"
```

This triggers the full BRAIN flow — Begin capture, Refine interview, Arrange proposal, then waits for explicit human approval before creating any files.

### Rules Governing Intents (from CLAUDE.md)

- Git commit **must occur before** starting each new intent
- If an intent fails — revert to the last intent boundary
- Never overwrite existing intent files
- Never renumber existing intents
- Never infer approval — always wait for explicit yes

### The Intent Lifecycle

```
/brain invoked
    ↓
Begin: raw dump captured in CONTEXT.md
    ↓
Refine: scope locked in CONTEXT.md
    ↓
Arrange: intents proposed (NOT created yet)
    ↓
Human approves → intent files created + Status.md updated
    ↓
Iterate: intent 01 → commit → intent 02 → commit → ...
    ↓
Next: human decides what comes after
```

---

## 3. The Disadvantages of Intents Alone

Despite being a solid planning framework, the BRAIN/Intents system has **critical gaps** when used in isolation.

### Gap 1 — Session Amnesia

Every new Claude Code session starts with zero memory. The AI has no recollection of:
- What was discussed and why decisions were made
- What was tried and rejected during a previous intent
- What the last working state was
- Any blockers that were resolved and how

**Result:** You must manually tell Claude to "read Status.md and the intent files first" — and even then, it only gets the structured data, not the reasoning behind it.

### Gap 2 — Token Cost of Session Resume

Resuming work requires Claude to re-read:
- `CONTEXT.md` (~500–800 tokens)
- `Status.md` (~200 tokens)
- Relevant intent file(s) (~300–600 tokens each)

**Cost per session resume: ~1,500–3,000 tokens** just to get back to where you were — before any actual work begins.

### Gap 3 — Decisions and Reasoning Are Not Captured

Intent files capture **what** was done and **whether it succeeded**. They do not capture:
- Why a particular approach was chosen over alternatives
- What was investigated and found to not work
- The specific reasoning chain that led to a decision
- Inline corrections and pivots made during Iterate

These are lost at session end, forever.

### Gap 4 — No Cross-Teammate Memory

If a teammate picks up a BRAIN intent mid-project, they must:
- Read all files manually
- Ask the original developer to explain context
- Risk missing nuance that wasn't written down

### Gap 5 — Relies on Human to Initiate Recall

Even if all intent files are perfectly written, Claude will not read them unless:
- The user explicitly says "read my intents first"
- Or the CLAUDE.md instructs it (which still requires the user to start the right session)

There is no automatic triggering mechanism built into BRAIN itself.

### Summary of Intent Gaps

| Gap | Impact | Frequency |
|---|---|---|
| Session amnesia | Context re-explanation every session | Every session |
| Token cost on resume | 1,500–3,000 wasted tokens | Every session |
| Lost reasoning/decisions | Incorrect pivots in future sessions | Medium |
| No teammate memory | Onboarding friction | Occasional |
| No auto-recall trigger | User must remember to prime Claude | Every session |

---

## 4. What is Aline?

Aline is a **persistent memory layer for AI-assisted development**. It records development activity as git commits — not just code changes, but the *context, reasoning, and progress* that normally vanishes when a session ends.

> GitHub: [https://github.com/human-re/GCC](https://github.com/human-re/GCC)
> npm: `aline-ai`

### Core Concept

Think of Aline as **version control for AI conversational context** — it runs alongside your coding session and captures what was done, why it was done, and where things stand. This context is then queryable by AI agents in future sessions.

### How It Works

```
Session in progress
    ↓
Aline runs in background (via MCP or CLI)
    ↓
Development activity captured as structured git commits
    ↓
Session ends → context preserved in git history
    ↓
Next session: "use aline" → agent recalls prior context
    ↓
Teammate pulls repo → they inherit full AI memory too
```

### Installation (Claude Code — MCP)

```bash
claude mcp add --scope user --transport stdio aline -- npx -y aline-ai@latest
```

Verify with:
```bash
claude mcp list
```

### Key Capabilities

| Capability | Description |
|---|---|
| **Auto-capture** | Records activity without explicit user action |
| **Semantic commits** | Structured commits carry meaning, not just diffs |
| **Session recall** | `"use aline"` retrieves prior context in any new session |
| **Cross-model** | Works across Claude, GPT, and other AI models |
| **Team sharing** | Push to GitHub → teammates inherit full AI memory |
| **Project isolation** | Each project has its own memory layer |

### Triggering Aline

```
# Recall prior context
"use aline — what was I last working on in {project}?"

# Commit current context
"use aline — commit: intent 03 complete, BasePage class created"

# Team recall
"use aline — what did the team previously investigate about auth?"
```

---

## 5. The Disadvantages of Aline Alone

Aline is powerful but has its own limitations when used without a structured planning framework.

### Gap 1 — No Structure or Planning Layer

Aline captures context but does not organize work. Without BRAIN:
- No defined scope or Definition of Done
- No intent boundaries to commit against
- No approval gates before work starts
- Risk of scope creep — Aline records everything including wrong turns

### Gap 2 — Memory Quality Depends on What Gets Committed

Aline's recall is only as good as what gets captured. If sessions are unstructured:
- Commits are generic and low-signal ("worked on auth stuff")
- Recall returns noisy, unfocused context
- Future sessions still struggle to orient themselves

### Gap 3 — No Phase-Gate Awareness

Aline does not know the difference between:
- A decision that was approved vs. one still under discussion
- A completed intent vs. one that was abandoned
- The beginning of a feature vs. the middle of debugging it

Without BRAIN's phase structure, Aline cannot produce meaningfully segmented memory.

### Gap 4 — Hook-Based Auto-Trigger is Too Broad

Using Claude Code hooks (`Stop`, `UserPromptSubmit`) to auto-trigger Aline:
- `Stop` fires after **every Claude response turn** — too frequent, commits become noise
- `UserPromptSubmit` fires on **every user prompt** — recall runs constantly, wastes tokens
- Neither fires at semantically meaningful moments

### Gap 5 — Commit Messages Lack Semantic Context

Without a framework telling Aline *why* a commit is happening, commit messages default to generic session summaries rather than meaningful checkpoints like:
- "Arrange approved: 5 intents for UserAuthentication feature"
- "Intent 02 complete: PlaywrightConfig working with 4 environments"

### Summary of Aline Gaps

| Gap | Impact | Severity |
|---|---|---|
| No planning/structure layer | Uncontrolled scope, no DoD | High |
| Memory quality = commit quality | Low-signal recall in unstructured sessions | High |
| No phase-gate awareness | Cannot distinguish approved vs. exploratory work | Medium |
| Hook triggers too broad | Noisy commits, wasteful recall | Medium |
| Generic commit messages | Future recall lacks precision | Medium |

---

## 6. Why They Are a Perfect Complement

BRAIN and Aline address **exactly each other's gaps**. Together they form a complete system.

```
BRAIN provides:                    Aline provides:
─────────────────────              ──────────────────────
Structure and planning        ←→   Persistent memory
Phase gates and approval      ←→   Cross-session continuity
Definition of Done            ←→   Automatic context capture
Meaningful commit boundaries  ←→   Queryable memory at those boundaries
What needs to be done         ←→   Why decisions were made
Static markdown files         ←→   Dynamic, searchable context layer
Human owns "Actual" time      ←→   AI captures reasoning automatically
```

### The Complementary Loop

```
/brain invoked
    ↓
Aline recalls: "Last time on {IdeaTitle}: intent 02 was done,
                intent 03 was blocked on tsconfig ESM issue"
    ↓
Begin + Refine: scope locked (CONTEXT.md updated)
    ↓
Aline commits: "BRAIN Refine complete — scope locked for {IdeaFolder}"
    ↓
Arrange: intents proposed → human approves
    ↓
Aline commits: "BRAIN Arrange approved — 5 intents for {IdeaFolder}"
    ↓
Iterate intent 01 → done
    ↓
Aline commits: "Intent 01 done: FolderStructure created, e2e/ subdirs in place"
    ↓
Iterate intent 02 → done
    ↓
Aline commits: "Intent 02 done: PlaywrightConfig — 4 envs, Chromium only"
    ↓
... and so on
    ↓
Next session: "use aline" → agent knows exactly where to resume
              without reading a single markdown file
```

### Token Savings Comparison

| Scenario | BRAIN Alone | BRAIN + Aline |
|---|---|---|
| Session resume | ~2,000 tokens (re-read files) | ~200 tokens (aline recall) |
| Decision recall | Manual re-explanation | Automatic from memory |
| Teammate onboarding | Read all files + ask questions | Pull repo → `use aline` |
| Blocker re-investigation | Full re-trace from scratch | Prior session notes surface instantly |
| **Estimated saving per session** | — | **~70–80% context overhead reduction** |

### Quality Improvement Comparison

| Concern | BRAIN Alone | Aline Alone | BRAIN + Aline |
|---|---|---|---|
| Structured planning | ✅ | ❌ | ✅ |
| Session continuity | ❌ | ✅ | ✅ |
| Meaningful commits | ✅ (manual) | ❌ (generic) | ✅ (phase-gated) |
| Decision reasoning captured | ❌ | ✅ | ✅ |
| Auto recall on resume | ❌ | ✅ | ✅ |
| DoD enforcement | ✅ | ❌ | ✅ |
| Cross-teammate memory | ❌ | ✅ | ✅ |
| No manual priming needed | ❌ | Partially | ✅ |

---

## 7. Recommended Integration Architecture

### Primary Mechanism — BRAIN-Embedded Aline

Embed Aline calls directly into the `/brain` skill at each phase gate. BRAIN already controls the workflow — Aline becomes a natural participant at the exact right moments.

```
Phase Gate                    Aline Action
──────────────────────────    ────────────────────────────────────────────────
/brain invoked            →   Recall: "use aline — prior context on {IdeaTitle}"
Refine complete           →   Commit: "BRAIN Refine locked — {IdeaFolder} scope set"
Arrange approved          →   Commit: "BRAIN Arrange approved — intents 01–N for {IdeaFolder}"
Each intent completes     →   Commit: "Intent {N} done: {ShortName} — {outcome summary}"
Blocker encountered       →   Commit: "Intent {N} blocked: {blocker description}"
Next phase (human decides) →  Commit: "Session end — {IdeaFolder} status: {Active|Paused}"
```

**Why this is the right approach:**
- Commits happen at semantically meaningful moments, not on every Claude response
- Recall is targeted to the specific idea being worked on, not generic
- Zero extra user effort — embedded in the flow they already follow
- High-signal memory: every Aline commit maps to a real BRAIN phase event

### Safety Net — Minimal Stop Hook

A single lightweight `Stop` hook captures anything that happens **outside** a BRAIN session (exploratory work, quick fixes, debugging). This is not the primary mechanism — just a fallback.

```json
// .claude/settings.json (project-level)
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "npx aline-ai@latest commit --message 'auto: session checkpoint'"
          }
        ]
      }
    ]
  }
}
```

**Why only Stop, not UserPromptSubmit:**
- `UserPromptSubmit` fires on every prompt → recall runs constantly → wasteful
- `Stop` fires per turn → more frequent but silent background commits → acceptable
- BRAIN-embedded calls already handle the high-quality commits

### Architecture Summary

```
┌──────────────────────────────────────────────────────────┐
│           PRIMARY: BRAIN-Embedded Aline                  │
│                                                          │
│   /brain → recall → Refine → commit → Arrange → commit  │
│   → Intent done → commit → Intent done → commit → ...   │
│                                                          │
│   High-signal. Phase-gated. Semantically meaningful.     │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│           SAFETY NET: Stop Hook                          │
│                                                          │
│   Fires silently after every Claude turn.               │
│   Captures non-BRAIN work (quick fixes, exploration).   │
│   Low-signal but complete coverage.                      │
└──────────────────────────────────────────────────────────┘
```

---

## 8. Implementation Plan

When ready to implement, the following changes are needed:

### Step 1 — Install Aline MCP

```bash
claude mcp add --scope user --transport stdio aline -- npx -y aline-ai@latest
claude mcp list   # verify it appears
```

### Step 2 — Modify `brain.md` Skill

Add the following at each phase gate inside `.claude/commands/brain.md`:

- **Top of execution order (before Step 1):**
  Instruct Claude to call: `"use aline — recall prior context for {IdeaTitle}"`

- **After Refine interview complete:**
  Instruct Claude to call: `"use aline — commit: Refine locked for {IdeaFolder}"`

- **After Arrange approval (Step 7 in brain.md):**
  Instruct Claude to call: `"use aline — commit: Arrange approved, intents 01–N created for {IdeaFolder}"`

- **After each intent marked Done during Iterate:**
  Instruct Claude to call: `"use aline — commit: Intent {N} {ShortName} done — {outcome}"`

- **At Next phase:**
  Instruct Claude to call: `"use aline — commit: session end, {IdeaFolder} status is {status}"`

### Step 3 — Add Stop Hook (Safety Net)

Create or update `.claude/settings.json` in this project with the Stop hook configuration shown in Section 7.

### Step 4 — Session Start Convention

At the start of any new session (BRAIN or otherwise), the embedded recall handles it. No manual priming needed after Step 2 is complete.

---

> **This document is the strategy reference. The actual implementation requires modifying `brain.md` and setting up the Aline MCP. See Section 8 for the implementation plan.**

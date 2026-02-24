# Claude Command: /dissolve — Intent & Feature Dissolution

> **Purpose:** Dissolve a completed intent by extracting its learnings into persistent memory, then removing the intent file. If all intents in a feature folder are dissolved, offer to dissolve the feature folder itself. Keeps the repo permanently lean for both finite and ongoing projects.

## Invocation

```
/dissolve "{IdeaFolder}" {IntentNumber}
```

**Examples:**
```
/dissolve "UserAuthentication" 2
/dissolve "PlaywrightScaffold" 5
```

---

## Two Levels of Dissolution

### Level 1 — Intent Dissolution
Dissolves a single intent file. Triggered after each intent is marked Done.

### Level 2 — Feature Folder Dissolution
Dissolves the entire feature folder (`CONTEXT.md` + `Status.md`). Triggered automatically after the **last intent** in a folder reaches `Dissolved ✓` — cascades from Level 1.

---

## What Each Level Does

### Level 1 — Intent

```
Intent file exists and is Done
  ↓
Extract: Goal, Outcome, Key Decisions, Follow-ups
  ↓
Append entry to Memory/{IdeaFolder}.md
  ↓
Aline commit: "dissolved intent {N} {ShortName} — {outcome}"
  ↓
Delete intent file
  ↓
Update Status.md row → Dissolved ✓
  ↓
Check: are ALL intents in the folder now Dissolved ✓?
  ↓ yes
→ Trigger Level 2 prompt
```

### Level 2 — Feature Folder

```
All intents in {IdeaFolder} are Dissolved ✓
  ↓
Claude prompts: "All intents in {IdeaFolder} are dissolved.
  Want to dissolve the feature folder too?
  This will: extract scope + full status from CONTEXT.md and Status.md
  → append a Feature Summary to Memory/{IdeaFolder}.md
  → Aline commit
  → delete CONTEXT.md, Status.md, and the folder"
  ↓
User: yes →
  1. Read CONTEXT.md — extract Goal, scope, constraints, DoD
  2. Read Status.md — extract full intent table + project state
  3. Append Feature Summary block to Memory/{IdeaFolder}.md
  4. Aline commit: "dissolved feature {IdeaFolder} — all intents complete"
  5. Delete CONTEXT.md and Status.md
  6. Delete the now-empty Intents/{IdeaFolder}/ folder

User: no → folder stays as lightweight archive, no action
```

---

## End State

```
Intents/
  WidgetsFeature/        ← active, has live intent files
  TeamsFeature/          ← active, has live intent files
                         ← completed features: folder gone

Memory/
  LoginFeature.md        ← full history: all intents + feature summary
  DashboardFeature.md    ← full history: all intents + feature summary
  WidgetsFeature.md      ← grows as intents dissolve (feature folder still active)
```

---

## Execution Order

### Level 1 — Intent Dissolution

1. **Locate** the intent file: `Intents/{IdeaFolder}/{N}-*.md`
   - If not found: stop and report — do not proceed
   - If Status row is not Done: warn user, ask for confirmation before dissolving

2. **Read** the intent file fully

3. **Extract** the following fields:
   - `Goal` — from the intent's Goal field
   - `Outcome` — from the Outcome → Result field
   - `Key Decisions` — from the Outcome → Key Decisions field
   - `Follow-ups` — from the Outcome → Follow-ups field
   - `Actual Time` — from the Outcome → Actual Time field

4. **Append** intent entry to `Memory/{IdeaFolder}.md`:
   - Create the file from template if it does not exist
   - Append — never overwrite

   ```md
   ## Intent {N} — {ShortName}
   **Dissolved:** {YYYY-MM-DD}
   **Goal:** {goal}
   **Outcome:** {result}
   **Key Decisions:** {key decisions}
   **Follow-ups:** {follow-ups}
   **Actual Time:** {actual time}

   ---
   ```

5. **Aline commit:**
   > `use aline — commit: dissolved intent {N} {ShortName} for {IdeaFolder} — {one-line outcome}`

6. **Delete** the intent file: `Intents/{IdeaFolder}/{N}-*.md`

7. **Update** `Status.md` row → `Dissolved ✓`

8. **Check** if all rows in Status.md are now `Dissolved ✓`
   - If yes → proceed to Level 2 prompt
   - If no → report and stop:
     > "Intent {N} ({ShortName}) dissolved. {X} intent file(s) remaining in `Intents/{IdeaFolder}/`."

---

### Level 2 — Feature Folder Dissolution

9. **Prompt** the user:
   > "All intents in {IdeaFolder} are dissolved. Want to dissolve the feature folder too?
   > This will collapse CONTEXT.md + Status.md into `Memory/{IdeaFolder}.md`, commit to Aline, and delete the folder."

10. If **yes**:

    a. Read `CONTEXT.md` — extract Goal, scope, constraints, Definition of Done

    b. Read `Status.md` — extract full intent table and final project state

    c. **Append** Feature Summary block to `Memory/{IdeaFolder}.md`:

    ```md
    ## Feature Summary — {IdeaTitle}
    **Dissolved:** {YYYY-MM-DD}
    **Goal:** {from CONTEXT.md}
    **Scope:** {in/out of scope from CONTEXT.md}
    **Definition of Done:** {from CONTEXT.md}
    **Final Status:** {from Status.md project state}
    **Intent Count:** {total intents completed}

    ---
    ```

    d. **Aline commit:**
       > `use aline — commit: dissolved feature {IdeaFolder} — all {N} intents complete, feature closed`

    e. **Delete** `CONTEXT.md` and `Status.md`

    f. **Delete** the now-empty `Intents/{IdeaFolder}/` folder

    g. **Report:**
       > "Feature {IdeaFolder} fully dissolved. Full history preserved in `Memory/{IdeaFolder}.md`. Folder removed from `Intents/`."

11. If **no** → folder stays as a lightweight archive. No action.

---

## Memory File Template (created on first dissolution)

```md
# Memory — {IdeaTitle}

> Auto-generated by /dissolve. Append-only — do not manually edit entries.
> Human-readable distilled log of all dissolved intents and feature summary.
> AI-readable via Aline commits.

---
```

---

## Safety Rules

- **Never dissolve** an intent that is not marked Done — warn and ask for confirmation
- **Never overwrite** existing Memory entries — always append
- **Never skip the Level 2 prompt** — folder deletion always requires explicit user yes
- **Never dissolve** multiple intents in a single command — one at a time only
- If the Outcome section is empty: warn user that dissolution will produce low-quality memory, ask to confirm
- Level 2 is **optional** — user can always say no and keep the folder as a lightweight archive

---

## Notes

- Dissolution is **irreversible** for local files — but content is preserved in:
  1. `Memory/{IdeaFolder}.md` (distilled summary — human-readable)
  2. Aline git history (AI-queryable context)
  3. Standard git history (full diff if committed before deletion)
- For ongoing projects: intents dissolve regularly, feature folders dissolve when a feature is fully shipped
- `Intents/` stays permanently lean — only folders with active work exist at any time

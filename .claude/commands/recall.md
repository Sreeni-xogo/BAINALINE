# /recall — Session Memory Search

> Recover a decision or lost context from raw JSONL session history.
> Use when /compact has dropped context or you need to find a past decision.

## Steps

### 1. Find the JSONL file

Check `Memory/.local/decisions.md` first — the PreCompact hook logs each JSONL path there.
If it exists, find the most recent `## Compact:` entry and note the JSONL path.

If `decisions.md` is missing, find the most recent JSONL directly:
```
find ~/.claude/projects -name "*.jsonl" | xargs ls -t 2>/dev/null | head -5
```

### 2. Search the JSONL

Run the search utility with the keyword from the user's query:
```
python3 .claude/hooks/search-jsonl.py <jsonl-file-path> <keyword>
```

Try multiple keywords if the first has no matches:
- The exact topic word (e.g. `auth`, `endpoint`, `framework`)
- `DECISION` — finds all labeled decisions in compact summaries
- A filename, function name, or variable related to the topic

### 3. Report results

Return:
- The line number where the decision/context was found
- The relevant content (truncated to the key part)
- The session file it came from

### 4. If nothing found

- Fall back to `Memory/_sessions.md` for high-level phase summaries
- Fall back to `Memory/{IdeaFolder}.md` for dissolved intent outcomes
- Note: "No JSONL match found for '{topic}'" and suggest alternative keywords

## Notes
- `Memory/.local/decisions.md` is gitignored — machine-local only
- The PreCompact hook labels decisions as `DECISION [topic]:` in compact summaries
- Try `DECISION` as a keyword to find all preserved decisions at once

$ARGUMENTS

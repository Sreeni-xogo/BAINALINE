#!/usr/bin/env bash
# PreCompact hook: records session JSONL reference and outputs structured
# summarization instructions so key decisions survive compaction.
#
# Writes to: {PROJECT_DIR}/Memory/.local/decisions.md (gitignored)
# Compatible with: Windows Git Bash + Linux/Mac

INPUT=$(cat)  # JSON: { "trigger": "manual"|"auto", "custom_instructions": "..." }

SESSION_ID="${CLAUDE_SESSION_ID:-}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Convert project dir path to Claude's encoded projects directory name.
# Windows Git Bash: /d/XOGO/BAINALINE  -> D--XOGO-BAINALINE
# Linux/Mac:        /home/user/project  -> -home-user-project
if [[ "$PROJECT_DIR" =~ ^/[a-zA-Z]/ ]]; then
    # Windows Git Bash path (e.g. /d/XOGO/BAINALINE)
    DRIVE=$(echo "$PROJECT_DIR" | cut -c2 | tr '[:lower:]' '[:upper:]')
    REST=$(echo "$PROJECT_DIR" | cut -c4-)
    ENCODED="${DRIVE}--$(echo "$REST" | sed 's|/|-|g')"
else
    # Linux/Mac path (e.g. /home/user/project)
    ENCODED=$(echo "$PROJECT_DIR" | sed 's|/|-|g; s|_|-|g')
fi

PROJECTS_BASE="$HOME/.claude/projects"
PROJECT_STORE="$PROJECTS_BASE/$ENCODED"

# Store decisions inside the project's gitignored Memory/.local/
MEMORY_DIR="$PROJECT_DIR/Memory/.local"
DECISIONS_FILE="$MEMORY_DIR/decisions.md"

mkdir -p "$MEMORY_DIR"

# Find the JSONL file for this session
JSONL_FILE=""
if [ -n "$SESSION_ID" ]; then
    JSONL_FILE=$(find "$PROJECT_STORE" -maxdepth 1 -name "${SESSION_ID}.jsonl" 2>/dev/null | head -1)
fi

# If not found by session ID, take the most recently modified JSONL
if [ -z "$JSONL_FILE" ]; then
    JSONL_FILE=$(ls -t "$PROJECT_STORE"/*.jsonl 2>/dev/null | head -1)
fi

LINE_COUNT=0
if [ -f "$JSONL_FILE" ]; then
    LINE_COUNT=$(wc -l < "$JSONL_FILE")
fi

# Append a compact event record to decisions.md
{
    echo ""
    echo "## Compact: $(date '+%Y-%m-%d %H:%M') | session=${SESSION_ID:-unknown}"
    echo "- JSONL: ${JSONL_FILE:-not found}"
    echo "- Lines at compact: $LINE_COUNT"
    echo "- Search: python3 .claude/hooks/search-jsonl.py \"${JSONL_FILE}\" \"<keyword>\""
} >> "$DECISIONS_FILE"

# Output custom compaction instructions (Claude uses this as the summary prompt)
cat <<'INSTRUCTIONS'
When creating this compact summary, you MUST preserve the following in a structured way:

1. DECISIONS — for each significant technical choice, write:
   DECISION [topic]: <what was decided> | Reason: <why>
   (e.g. DECISION [auth method]: cookie-based via curl | Reason: page requires session auth)

2. CONFIGS — all file paths, API endpoints, credentials patterns, env vars established.

3. PROGRESS — what tasks were completed, what is in-flight, and the exact next step.

4. ERRORS — problems encountered and how they were resolved.

5. OPEN QUESTIONS — anything deferred or unresolved.

Use these exact labels (DECISION, CONFIGS, PROGRESS, ERRORS, OPEN QUESTIONS) so they
can be grepped from the JSONL or found by the /recall command after compaction.
INSTRUCTIONS

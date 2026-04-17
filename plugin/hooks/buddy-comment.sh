#!/bin/bash
# Stop hook: extract <!-- buddy: ... --> comments from Claude's response
# Receives JSON on stdin with the assistant's message

STATE_DIR="$HOME/.claude-buddy"
STATUS_FILE="$STATE_DIR/status.json"

# Exit silently if no status file
[ -f "$STATUS_FILE" ] || exit 0

# Check if muted
MUTED=$(jq -r '.muted // false' < "$STATUS_FILE" 2>/dev/null)
[ "$MUTED" = "true" ] && exit 0

# Read the hook input from stdin
INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null)
SESSIONS_DIR="$STATE_DIR/sessions"
TTYS_DIR="$STATE_DIR/tty-sessions"

# Extract the assistant's last message
RESPONSE=$(echo "$INPUT" | jq -r '.last_assistant_message // .stop_response // ""' 2>/dev/null)
[ -z "$RESPONSE" ] && exit 0

# Extract buddy comment using sed (macOS-compatible, no grep -P)
# Pattern: <!-- buddy: some text here -->
COMMENT=$(echo "$RESPONSE" | sed -n 's/.*<!-- buddy: \(.*\) -->.*/\1/p' | head -1)
[ -z "$COMMENT" ] && exit 0

# Write per-session reaction file and TTY→session mapping
if [ -n "$SESSION_ID" ]; then
  mkdir -p "$SESSIONS_DIR"
  jq -n --arg sid "$SESSION_ID" --arg r "$COMMENT" --arg t "$(date +%s)000" \
    '{"session_id":$sid,"reaction":$r,"reactionAt":($t|tonumber)}' \
    > "$SESSIONS_DIR/${SESSION_ID}.tmp" && mv "$SESSIONS_DIR/${SESSION_ID}.tmp" "$SESSIONS_DIR/${SESSION_ID}.json"
  MY_TTY=$(ps -o tty= -p $$ 2>/dev/null | tr -d ' ')
  if [ -n "$MY_TTY" ] && [ "$MY_TTY" != "??" ] && [ "$MY_TTY" != "-" ]; then
    mkdir -p "$TTYS_DIR"
    echo "$SESSION_ID" > "$TTYS_DIR/$MY_TTY"
  fi
fi

# Mirror to global status.json (most-recently-active display)
jq --arg r "$COMMENT" --arg t "$(date +%s)000" \
  '.reaction = $r | .reactionAt = ($t | tonumber)' \
  "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"

exit 0

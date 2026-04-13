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

# Extract the assistant's last message
RESPONSE=$(echo "$INPUT" | jq -r '.last_assistant_message // .stop_response // ""' 2>/dev/null)
[ -z "$RESPONSE" ] && exit 0

# Extract buddy comment using sed (macOS-compatible, no grep -P)
# Pattern: <!-- buddy: some text here -->
COMMENT=$(echo "$RESPONSE" | sed -n 's/.*<!-- buddy: \(.*\) -->.*/\1/p' | head -1)
[ -z "$COMMENT" ] && exit 0

# Update the status file with the extracted comment
jq --arg r "$COMMENT" --arg t "$(date +%s)000" \
  '.reaction = $r | .reactionAt = ($t | tonumber)' \
  "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"

exit 0

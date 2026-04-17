#!/bin/bash
# PostToolUse hook: detect errors and test failures in Bash output
# Receives JSON on stdin with tool_input and tool_output fields

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

# Get the tool output (Bash command result)
OUTPUT=$(echo "$INPUT" | jq -r '.tool_output // ""' 2>/dev/null)
[ -z "$OUTPUT" ] && exit 0

# Detect errors
REACTION=""
EVENT=""

# Check for common error patterns
if echo "$OUTPUT" | grep -qi -E '(error|Error|ERROR|FAILED|failed|Failed|panic|PANIC|exception|Exception|traceback|Traceback|fatal|FATAL)'; then
  # Check if it's a test failure specifically
  if echo "$OUTPUT" | grep -qi -E '(test.*fail|fail.*test|FAIL|jest|pytest|mocha|vitest|cargo test)'; then
    EVENT="test-fail"
  else
    EVENT="error"
  fi
fi

# Check for success patterns
if [ -z "$EVENT" ]; then
  if echo "$OUTPUT" | grep -qi -E '(passed|success|✓|✔|PASS|All tests|Build succeeded|compiled successfully)'; then
    EVENT="success"
  fi
fi

# If we detected an event, update the status file with a reaction
if [ -n "$EVENT" ]; then
  # Load companion for species-aware reactions (done by the MCP server)
  # For the hook, we just write a simple marker that the status line can pick up
  COMPANION_FILE="$STATE_DIR/companion.json"
  if [ -f "$COMPANION_FILE" ]; then
    SPECIES=$(jq -r '.bones.species // "blob"' < "$COMPANION_FILE" 2>/dev/null)
    # Pick a simple reaction based on event
    case "$EVENT" in
      error)
        REACTIONS=("Oof!" "Bug detected!" "Let's fix this" "Hmm..." "That's not right")
        ;;
      test-fail)
        REACTIONS=("Tests failed!" "Red!" "Back to it!" "Almost!" "Try again!")
        ;;
      success)
        REACTIONS=("Nice!" "Ship it!" "Clean!" "Nailed it!" "Yes!")
        ;;
    esac
    # Pick pseudo-random reaction
    IDX=$(( $(date +%s) % ${#REACTIONS[@]} ))
    REACTION="${REACTIONS[$IDX]}"

    # Write per-session reaction file and TTY→session mapping
    if [ -n "$SESSION_ID" ]; then
      mkdir -p "$SESSIONS_DIR"
      jq -n --arg sid "$SESSION_ID" --arg r "$REACTION" --arg t "$(date +%s)000" \
        '{"session_id":$sid,"reaction":$r,"reactionAt":($t|tonumber)}' \
        > "$SESSIONS_DIR/${SESSION_ID}.tmp" && mv "$SESSIONS_DIR/${SESSION_ID}.tmp" "$SESSIONS_DIR/${SESSION_ID}.json"
      MY_TTY=$(ps -o tty= -p $$ 2>/dev/null | tr -d ' ')
      if [ -n "$MY_TTY" ] && [ "$MY_TTY" != "??" ] && [ "$MY_TTY" != "-" ]; then
        mkdir -p "$TTYS_DIR"
        echo "$SESSION_ID" > "$TTYS_DIR/$MY_TTY"
      fi
    fi

    # Mirror to global status.json (most-recently-active display)
    jq --arg r "$REACTION" --arg t "$(date +%s)000" \
      '.reaction = $r | .reactionAt = ($t | tonumber)' \
      "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
  fi
fi

exit 0

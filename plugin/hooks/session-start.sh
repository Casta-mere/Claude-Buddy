#!/bin/bash
# SessionStart hook: greet new sessions, restore resumed session reactions

STATE_DIR="$HOME/.claude-buddy"
STATUS_FILE="$STATE_DIR/status.json"
SESSIONS_DIR="$STATE_DIR/sessions"
TTYS_DIR="$STATE_DIR/tty-sessions"
GREETINGS_FILE="$STATE_DIR/greetings.txt"

[ -f "$STATUS_FILE" ] || exit 0
MUTED=$(jq -r '.muted // false' < "$STATUS_FILE" 2>/dev/null)
[ "$MUTED" = "true" ] && exit 0

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null)
# Fallback: SessionStart may pass session_id via env var instead of stdin
[ -z "$SESSION_ID" ] && SESSION_ID="${CLAUDE_SESSION_ID:-}"
[ -z "$SESSION_ID" ] && exit 0

SESSION_FILE="$SESSIONS_DIR/${SESSION_ID}.json"
MY_TTY=$(ps -o tty= -p $$ 2>/dev/null | tr -d ' ')

write_tty_mapping() {
  if [ -n "$MY_TTY" ] && [ "$MY_TTY" != "??" ] && [ "$MY_TTY" != "-" ]; then
    mkdir -p "$TTYS_DIR"
    echo "$SESSION_ID" > "$TTYS_DIR/$MY_TTY"
  fi
}

if [ -f "$SESSION_FILE" ]; then
  # Resumed session: re-bind TTY so status line shows this session's last reaction
  write_tty_mapping
  exit 0
fi

# New session: pick a greeting
GREETING=""
if [ -f "$GREETINGS_FILE" ]; then
  GREETING=$(awk -v seed="$(( $(date +%s) + $$ ))" \
    '!/^[[:space:]]*#/ && NF > 0 {lines[++n]=$0} END {if(n>0) print lines[(seed%n)+1]}' \
    "$GREETINGS_FILE")
fi

# Fallback if greetings file missing or empty
if [ -z "$GREETING" ]; then
  DEFAULTS=(
    "ready when you are"
    "let's build something"
    "fully charged, awaiting input"
    "here we go again"
    "what are we making today"
    "reporting for duty"
    "fresh session, fresh ideas"
    "coffee ready, bugs beware"
  )
  IDX=$(( ( $(date +%s) + $$ ) % ${#DEFAULTS[@]} ))
  GREETING="${DEFAULTS[$IDX]}"
fi

# Write session file with greeting
mkdir -p "$SESSIONS_DIR"
jq -n --arg sid "$SESSION_ID" --arg r "$GREETING" --arg t "$(date +%s)000" \
  '{"session_id":$sid,"reaction":$r,"reactionAt":($t|tonumber)}' \
  > "${SESSION_FILE}.tmp" && mv "${SESSION_FILE}.tmp" "$SESSION_FILE"

# Bind TTY to this session
write_tty_mapping

# Mirror to global status.json
jq --arg r "$GREETING" --arg t "$(date +%s)000" \
  '.reaction = $r | .reactionAt = ($t | tonumber)' \
  "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"

exit 0

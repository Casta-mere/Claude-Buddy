#!/bin/bash
# Claude Buddy diagnostic check

BUDDY_DIR="$HOME/.claude-buddy"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

pass() { printf "  ${GREEN}✓${RESET} %s\n" "$1"; }
fail() { printf "  ${RED}✗${RESET} %s\n" "$1"; FAILURES=$((FAILURES + 1)); }
warn() { printf "  ${YELLOW}!${RESET} %s\n" "$1"; }

FAILURES=0

echo ""
echo -e "${BOLD}🐾 Claude Buddy Doctor${RESET}"
echo -e "${DIM}──────────────────────${RESET}"
echo ""

# --- Prerequisites ---
echo -e "${BOLD}Prerequisites${RESET}"

if command -v node &>/dev/null; then
  pass "Node.js $(node -v)"
else
  fail "Node.js not found"
fi

if command -v jq &>/dev/null; then
  pass "jq found"
else
  fail "jq not found (brew install jq)"
fi

if [ -d "$HOME/.claude" ]; then
  pass "~/.claude/ exists"
else
  fail "~/.claude/ not found — run Claude Code first"
fi

echo ""

# --- Installed files ---
echo -e "${BOLD}Installed Files${RESET}"

if [ -f "$BUDDY_DIR/bin/buddy-server.mjs" ]; then
  pass "MCP server bundle"
else
  fail "MCP server missing ($BUDDY_DIR/bin/buddy-server.mjs)"
fi

if [ -f "$BUDDY_DIR/plugin/.claude-plugin/plugin.json" ]; then
  pass "Plugin manifest"
else
  fail "Plugin manifest missing"
fi

if [ -f "$BUDDY_DIR/plugin/.mcp.json" ]; then
  pass "MCP config"
else
  fail "MCP config missing"
fi

if [ -f "$BUDDY_DIR/plugin/skills/buddy/SKILL.md" ]; then
  pass "Buddy skill"
else
  fail "Buddy skill missing"
fi

if [ -f "$BUDDY_DIR/plugin/hooks/hooks.json" ]; then
  pass "Hooks config"
else
  fail "Hooks config missing"
fi

if [ -x "$BUDDY_DIR/statusline/buddy-status.sh" ]; then
  pass "Status line script (executable)"
else
  fail "Status line script missing or not executable"
fi

echo ""

# --- State files ---
echo -e "${BOLD}Companion State${RESET}"

if [ -f "$BUDDY_DIR/companion.json" ]; then
  NAME=$(jq -r '.name // "?"' "$BUDDY_DIR/companion.json")
  SPECIES=$(jq -r '.species // "?"' "$BUDDY_DIR/companion.json")
  RARITY=$(jq -r '.rarity // "?"' "$BUDDY_DIR/companion.json")
  pass "Companion: $NAME the $SPECIES ($RARITY)"
else
  fail "No companion.json — run install again"
fi

if [ -f "$BUDDY_DIR/status.json" ]; then
  pass "Status file exists"
else
  fail "No status.json"
fi

echo ""

# --- Settings integration ---
echo -e "${BOLD}Claude Code Settings${RESET}"

if [ -f "$CLAUDE_SETTINGS" ]; then
  # Check pluginDirs
  HAS_PLUGIN=$(jq --arg dir "$BUDDY_DIR/plugin" '.pluginDirs // [] | index($dir)' "$CLAUDE_SETTINGS" 2>/dev/null)
  if [ "$HAS_PLUGIN" != "null" ] && [ -n "$HAS_PLUGIN" ]; then
    pass "Plugin directory registered"
  else
    fail "Plugin not in pluginDirs — add \"$BUDDY_DIR/plugin\" to pluginDirs in settings.json"
  fi

  # Check statusLine
  SL_CMD=$(jq -r '.statusLine.command // ""' "$CLAUDE_SETTINGS" 2>/dev/null)
  if echo "$SL_CMD" | grep -q "buddy-status"; then
    pass "Status line configured"
  else
    fail "Status line not configured"
  fi

  # Check permissions
  HAS_PERM=$(jq '.permissions.allow // [] | index("mcp__claude-buddy__*")' "$CLAUDE_SETTINGS" 2>/dev/null)
  if [ "$HAS_PERM" != "null" ] && [ -n "$HAS_PERM" ]; then
    pass "MCP permissions granted"
  else
    warn "MCP permissions not pre-approved (Claude will ask on first use)"
  fi
else
  fail "~/.claude/settings.json not found"
fi

echo ""

# --- Summary ---
echo -e "${DIM}──────────────────────${RESET}"
if [ "$FAILURES" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}All checks passed!${RESET}"
else
  echo -e "${RED}${BOLD}$FAILURES issue(s) found.${RESET} Run the installer to fix: bash scripts/install.sh"
fi
echo ""

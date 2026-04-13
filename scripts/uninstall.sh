#!/bin/bash
set -e

BUDDY_DIR="$HOME/.claude-buddy"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
CLAUDE_JSON="$HOME/.claude.json"
BUDDY_SKILL="$HOME/.claude/skills/buddy"

ESC=$'\033'
GREEN="${ESC}[0;32m"
BOLD="${ESC}[1m"
DIM="${ESC}[2m"
RESET="${ESC}[0m"

info()  { printf "\033[0;34m[info]\033[0m  %s\n" "$1"; }
ok()    { printf "${GREEN}[ok]${RESET}    %s\n" "$1"; }

echo ""
echo -e "${BOLD}🐾 Claude Buddy Uninstaller${RESET}"
echo ""

# Remove MCP server from ~/.claude.json
if [ -f "$CLAUDE_JSON" ]; then
  info "Removing MCP server from ~/.claude.json..."
  CLAUDE_DATA=$(cat "$CLAUDE_JSON")
  CLAUDE_DATA=$(echo "$CLAUDE_DATA" | jq 'del(.mcpServers["claude-buddy"])')
  echo "$CLAUDE_DATA" | jq '.' > "$CLAUDE_JSON"
  ok "MCP server removed"
fi

# Remove /buddy skill
if [ -d "$BUDDY_SKILL" ]; then
  info "Removing /buddy skill..."
  rm -rf "$BUDDY_SKILL"
  ok "Skill removed"
fi

# Revert settings.json
if [ -f "$CLAUDE_SETTINGS" ]; then
  info "Reverting Claude Code settings..."
  SETTINGS=$(cat "$CLAUDE_SETTINGS")

  # Remove buddy hooks
  SETTINGS=$(echo "$SETTINGS" | jq --arg dir "$BUDDY_DIR" '
    if .hooks.PostToolUse then
      .hooks.PostToolUse = [.hooks.PostToolUse[] | select(.hooks[0].command | contains("claude-buddy") | not)]
    else . end |
    if .hooks.Stop then
      .hooks.Stop = [.hooks.Stop[] | select(.hooks[0].command | contains("claude-buddy") | not)]
    else . end
  ')

  # Remove statusLine if it points to our script
  SETTINGS=$(echo "$SETTINGS" | jq '
    if .statusLine.command and (.statusLine.command | contains("claude-buddy")) then del(.statusLine) else . end
  ')

  # Remove MCP permission
  SETTINGS=$(echo "$SETTINGS" | jq '
    if .permissions.allow then
      .permissions.allow = [.permissions.allow[] | select(. != "mcp__claude-buddy__*")] |
      if (.permissions.allow | length) == 0 then del(.permissions.allow) else . end |
      if (.permissions | length) == 0 then del(.permissions) else . end
    else . end
  ')

  # Remove pluginDirs entry if exists
  SETTINGS=$(echo "$SETTINGS" | jq --arg dir "$BUDDY_DIR/plugin" '
    if .pluginDirs then
      .pluginDirs = [.pluginDirs[] | select(. != $dir)] |
      if (.pluginDirs | length) == 0 then del(.pluginDirs) else . end
    else . end
  ')

  echo "$SETTINGS" | jq '.' > "$CLAUDE_SETTINGS"
  ok "Settings reverted"
fi

# Remove buddy directory
if [ -d "$BUDDY_DIR" ]; then
  info "Removing $BUDDY_DIR..."
  rm -rf "$BUDDY_DIR"
  ok "Files removed"
fi

echo ""
echo -e "${GREEN}${BOLD}Claude Buddy has been uninstalled.${RESET}"
echo -e "${DIM}Your companion will be missed. 🐾${RESET}"
echo ""

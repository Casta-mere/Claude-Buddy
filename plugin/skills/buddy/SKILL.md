---
name: buddy
description: Interact with your coding companion — show card, pet, view stats, rename, or toggle reactions
disable-model-invocation: true
allowed-tools: mcp__claude-buddy__buddy_show mcp__claude-buddy__buddy_pet mcp__claude-buddy__buddy_stats mcp__claude-buddy__buddy_rename mcp__claude-buddy__buddy_mute mcp__claude-buddy__buddy_unmute
---

# Buddy — Your Coding Companion

You are routing a `/buddy` command. Parse the subcommand from `$ARGUMENTS` and call the appropriate MCP tool.

## Command Routing

| User types | Action |
|------------|--------|
| `/buddy` (no args) | Call `buddy_show` to display the companion card |
| `/buddy pet` | Call `buddy_pet` to pet the companion |
| `/buddy stats` | Call `buddy_stats` to show detailed stats |
| `/buddy rename <name>` | Call `buddy_rename` with the name argument |
| `/buddy off` | Call `buddy_mute` to silence reactions |
| `/buddy on` | Call `buddy_unmute` to re-enable reactions |

## Rules

- Always call the MCP tool — never fabricate buddy data
- Display the tool's output exactly as returned (it contains pre-formatted ASCII art)
- If the subcommand is not recognized, show the available commands listed above

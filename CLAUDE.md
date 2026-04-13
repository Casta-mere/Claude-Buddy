# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Claude-Buddy is an ASCII art coding companion plugin for Claude Code. It recreates the removed `/buddy` feature as a standalone plugin using MCP, skills, hooks, and status line scripts.

## Repository Info

- **Owner:** Casta-mere
- **Primary branch:** main
- **Runtime:** Node.js 18+ (no Bun)
- **Build:** esbuild bundles `src/` → `dist/buddy-server.mjs` (single file, no runtime deps)

## Build & Run

```bash
npm install          # install dev/build dependencies
npm run build        # bundle src/ → dist/buddy-server.mjs
npm run dev          # run MCP server directly via tsx (for development)
npm run show         # preview companion card in terminal
```

## Install to Claude Code

```bash
bash scripts/install.sh   # copies files to ~/.claude-buddy/, configures Claude Code
bash scripts/doctor.sh    # verify all integration points
bash scripts/uninstall.sh # clean removal
```

## Architecture

Four integration points, all from a single plugin:

1. **MCP Server** (`src/server.ts` → `dist/buddy-server.mjs`) — tools for buddy_show, buddy_pet, buddy_stats, buddy_rename, buddy_mute, buddy_unmute. System prompt injection for `<!-- buddy: ... -->` comments.
2. **Skill** (`plugin/skills/buddy/SKILL.md`) — routes `/claude-buddy:buddy` commands to MCP tools.
3. **Hooks** (`plugin/hooks/`) — PostToolUse detects errors in Bash output (`react.sh`), Stop extracts buddy comments (`buddy-comment.sh`).
4. **Status Line** (`statusline/buddy-status.sh`) — animated display reading `~/.claude-buddy/status.json`.

## Source Layout

- `src/engine.ts` — FNV-1a hash + mulberry32 PRNG, deterministic identity generation from account UUID
- `src/art.ts` — 18 species ASCII art (3 frames each), rarity colors, card rendering
- `src/reactions.ts` — species-aware and stat-influenced reaction templates
- `src/state.ts` — `~/.claude-buddy/` file persistence with atomic writes
- `src/server.ts` — MCP server entry point wiring all tools together

## Key Patterns

- **Atomic writes**: state.ts uses write-to-temp + `rename()` to prevent race conditions between the MCP server, hooks, and status line script
- **macOS compatibility**: shell scripts use `sed` not `grep -P`, `tput cols` not `/proc/`
- **No runtime deps**: esbuild bundles everything into one `.mjs` file; the installed version needs only `node` and `jq`

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

1. **MCP Server** (`src/server.ts` → `dist/buddy-server.mjs`) — tools for buddy_show, buddy_pet, buddy_stats, buddy_rename, buddy_mute, buddy_unmute, buddy_react. System prompt injection for `<!-- buddy: ... -->` comments. Reads `CLAUDE_SESSION_ID` env var to write per-session reaction files.
2. **Skill** (`plugin/skills/buddy/SKILL.md`) — routes `/claude-buddy:buddy` commands to MCP tools.
3. **Hooks** (`plugin/hooks/`) — three hooks:
   - `session-start.sh` (SessionStart) — greets new sessions from `greetings.txt`; re-binds TTY mapping on resume
   - `react.sh` (PostToolUse/Bash) — detects errors/successes in Bash output
   - `buddy-comment.sh` (Stop) — extracts `<!-- buddy: ... -->` comments from Claude's responses
4. **Status Line** (`statusline/buddy-status.sh`) — animated display; reads TTY-scoped `~/.claude-buddy/tty-sessions/{tty}` → `sessions/{id}.json`, falling back to `status.json`.

## Source Layout

- `src/engine.ts` — FNV-1a hash + mulberry32 PRNG, deterministic identity generation from account UUID
- `src/art.ts` — 18 species ASCII art (3 frames each), rarity colors, card rendering
- `src/reactions.ts` — species-aware and stat-influenced reaction templates
- `src/state.ts` — `~/.claude-buddy/` file persistence with atomic writes; per-session reaction storage in `sessions/`
- `src/server.ts` — MCP server entry point wiring all tools together

## Key Patterns

- **Atomic writes**: state.ts uses write-to-temp + `rename()` to prevent race conditions between the MCP server, hooks, and status line script
- **TTY-scoped sessions**: hooks read their controlling TTY via `ps -o tty= -p $$` and write `tty-sessions/{tty}` → session_id; the status line resolves this after its terminal-width walk (both share the same controlling TTY inherited from the Claude Code process)
- **macOS compatibility**: shell scripts use `sed` not `grep -P`, `tput cols` not `/proc/`
- **No runtime deps**: esbuild bundles everything into one `.mjs` file; the installed version needs only `node` and `jq`

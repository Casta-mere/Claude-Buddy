# Claude Buddy

Permanent ASCII art coding companion for Claude Code — survives every update.

An animated terminal pet that lives in your Claude Code status line, reacts to errors and successes, and has a unique personality generated from your account.

## Features

- 18 species (duck, cat, dragon, ghost, robot, axolotl, and more)
- 5 rarity tiers (Common, Uncommon, Rare, Epic, Legendary)
- Animated status line with speech bubbles
- Contextual reactions to errors, test failures, and successes
- Deterministic identity — same account always gets the same buddy
- Pet counter, stats, and personality
- Built as a Claude Code plugin using MCP, skills, and hooks

## Install

### Option A: From source (recommended)

```bash
git clone https://github.com/Casta-mere/Claude-Buddy.git
cd Claude-Buddy
npm install
npm run build
bash scripts/install.sh
```

### Option B: One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/Casta-mere/Claude-Buddy/main/scripts/install.sh | bash
```

### Option C: Homebrew

```bash
brew tap Casta-mere/claude-buddy
brew install claude-buddy
claude-buddy install
```

### Requirements

- Node.js 18+
- jq (`brew install jq`)
- Claude Code v2.1.80+

## Usage

Start Claude Code normally — your buddy appears in the status line automatically.

### Commands

| Command | Description |
|---------|-------------|
| `/claude-buddy:buddy` | Show your companion's full card |
| `/claude-buddy:buddy pet` | Pet your buddy |
| `/claude-buddy:buddy stats` | View detailed stats |
| `/claude-buddy:buddy rename <name>` | Rename (1-14 chars) |
| `/claude-buddy:buddy off` | Mute reactions |
| `/claude-buddy:buddy on` | Unmute reactions |

## Species

duck, goose, blob, cat, dragon, octopus, owl, penguin, turtle, snail, ghost, axolotl, capybara, cactus, robot, rabbit, mushroom, chonk

## Rarity

| Tier | Chance | Color | Stars |
|------|--------|-------|-------|
| Common | 60% | Gray | ★ |
| Uncommon | 25% | Green | ★★ |
| Rare | 10% | Blue | ★★★ |
| Epic | 4% | Purple | ★★★★ |
| Legendary | 1% | Gold | ★★★★★ |

## Stats

Each buddy has 5 stats (1-20) that influence their personality:

- **DEBUGGING** — bug-hunting instincts
- **PATIENCE** — calm under pressure
- **CHAOS** — unpredictability
- **WISDOM** — sage advice
- **SNARK** — sarcastic comments

## How It Works

Claude Buddy uses four Claude Code extension points:

1. **MCP Server** — provides tools for showing, petting, and managing your buddy. Injects a system prompt so Claude appends invisible `<!-- buddy: ... -->` comments.
2. **Skill** — routes `/claude-buddy:buddy` slash commands to MCP tools.
3. **Hooks** — PostToolUse detects errors/successes in Bash output. Stop hook extracts buddy comments from responses.
4. **Status Line** — animated bash script reads `~/.claude-buddy/status.json` and renders the buddy with a speech bubble.

## Troubleshooting

Run the diagnostic check:

```bash
bash scripts/doctor.sh
# or after brew install:
claude-buddy doctor
```

## Uninstall

```bash
bash ~/.claude-buddy/uninstall.sh
# or after brew install:
claude-buddy uninstall
```

## License

MIT

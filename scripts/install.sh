#!/bin/bash
set -e

# Claude Buddy Installer
# Installs directly into Claude Code's config dirs:
#   ~/.claude-buddy/          — server bundle + state files
#   ~/.claude/skills/buddy/   — /buddy slash command
#   ~/.claude/settings.json   — hooks + statusLine
#   ~/.claude.json            — MCP server registration

BUDDY_DIR="$HOME/.claude-buddy"
CLAUDE_DIR="$HOME/.claude"
CLAUDE_SETTINGS="$CLAUDE_DIR/settings.json"
CLAUDE_JSON="$HOME/.claude.json"
REPO_URL="https://github.com/Casta-mere/Claude-Buddy"

ESC=$'\033'
GREEN="${ESC}[0;32m"
YELLOW="${ESC}[1;33m"
RED="${ESC}[0;31m"
BLUE="${ESC}[0;34m"
BOLD="${ESC}[1m"
DIM="${ESC}[2m"
RESET="${ESC}[0m"

info()  { printf "${BLUE}[info]${RESET}  %s\n" "$1"; }
ok()    { printf "${GREEN}[ok]${RESET}    %s\n" "$1"; }
warn()  { printf "${YELLOW}[warn]${RESET}  %s\n" "$1"; }
err()   { printf "${RED}[error]${RESET} %s\n" "$1"; exit 1; }

echo ""
echo -e "${BOLD}🐾 Claude Buddy Installer${RESET}"
echo -e "${DIM}────────────────────────${RESET}"
echo ""

# --- Preflight checks ---

if ! command -v node &>/dev/null; then
  err "Node.js is required but not found. Install it from https://nodejs.org"
fi
NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
  err "Node.js 18+ is required (found $(node -v))"
fi
ok "Node.js $(node -v)"

if ! command -v jq &>/dev/null; then
  warn "jq is not installed. Trying to install with Homebrew..."
  if command -v brew &>/dev/null; then
    brew install jq
    ok "Installed jq"
  else
    err "jq is required. Install it with: brew install jq"
  fi
else
  ok "jq found"
fi

if [ ! -d "$CLAUDE_DIR" ]; then
  err "~/.claude/ not found. Run Claude Code at least once first."
fi
ok "Claude Code config found"

# --- Determine source ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" 2>/dev/null)" && pwd 2>/dev/null || echo "")"
SOURCE_DIR=""

if [ -f "$SCRIPT_DIR/../dist/buddy-server.mjs" ]; then
  SOURCE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
  info "Installing from local repo: $SOURCE_DIR"
elif [ -f "$SCRIPT_DIR/../package.json" ]; then
  SOURCE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
  info "Building from local repo..."
  cd "$SOURCE_DIR"
  npm install --silent 2>/dev/null
  npm run build 2>/dev/null
  ok "Built MCP server"
else
  TMPDIR=$(mktemp -d)
  trap "rm -rf $TMPDIR" EXIT
  info "Downloading Claude Buddy..."
  git clone --depth 1 --quiet "$REPO_URL.git" "$TMPDIR/claude-buddy" 2>/dev/null
  SOURCE_DIR="$TMPDIR/claude-buddy"
  cd "$SOURCE_DIR"
  npm install --silent 2>/dev/null
  npm run build 2>/dev/null
  ok "Downloaded and built"
fi

# --- Install files ---

info "Installing to $BUDDY_DIR..."

mkdir -p "$BUDDY_DIR/bin"
mkdir -p "$BUDDY_DIR/hooks"
mkdir -p "$BUDDY_DIR/statusline"

# Copy bundled MCP server
cp "$SOURCE_DIR/dist/buddy-server.mjs" "$BUDDY_DIR/bin/buddy-server.mjs"

# Copy hook scripts
cp "$SOURCE_DIR/plugin/hooks/react.sh" "$BUDDY_DIR/hooks/react.sh"
cp "$SOURCE_DIR/plugin/hooks/buddy-comment.sh" "$BUDDY_DIR/hooks/buddy-comment.sh"
chmod +x "$BUDDY_DIR/hooks/react.sh"
chmod +x "$BUDDY_DIR/hooks/buddy-comment.sh"

# Copy status line script
cp "$SOURCE_DIR/statusline/buddy-status.sh" "$BUDDY_DIR/statusline/buddy-status.sh"
chmod +x "$BUDDY_DIR/statusline/buddy-status.sh"

# Copy uninstall script
cp "$SOURCE_DIR/scripts/uninstall.sh" "$BUDDY_DIR/uninstall.sh"
chmod +x "$BUDDY_DIR/uninstall.sh"

ok "Files installed"

# --- Install /buddy skill (personal skill → ~/.claude/skills/buddy/) ---

info "Installing /buddy skill..."
mkdir -p "$CLAUDE_DIR/skills/buddy"
cp "$SOURCE_DIR/plugin/skills/buddy/SKILL.md" "$CLAUDE_DIR/skills/buddy/SKILL.md"

# Update the skill to use non-plugin tool names (no namespace prefix)
# The MCP server name in ~/.claude.json will be "claude-buddy"
# So tools are: mcp__claude-buddy__buddy_show etc.
ok "/buddy skill installed"

# --- Register MCP server in ~/.claude.json ---

info "Registering MCP server..."

if [ ! -f "$CLAUDE_JSON" ]; then
  echo '{}' > "$CLAUDE_JSON"
fi

# Add MCP server config
CLAUDE_DATA=$(cat "$CLAUDE_JSON")
CLAUDE_DATA=$(echo "$CLAUDE_DATA" | jq --arg dir "$BUDDY_DIR" '
  if .mcpServers then . else .mcpServers = {} end |
  .mcpServers["claude-buddy"] = {
    "command": "node",
    "args": [($dir + "/bin/buddy-server.mjs")]
  }
')
echo "$CLAUDE_DATA" | jq '.' > "$CLAUDE_JSON"
ok "MCP server registered in ~/.claude.json"

# --- Configure hooks + statusLine in settings.json ---

info "Configuring hooks and status line..."

if [ ! -f "$CLAUDE_SETTINGS" ]; then
  echo '{}' > "$CLAUDE_SETTINGS"
fi

SETTINGS=$(cat "$CLAUDE_SETTINGS")

# Remove old pluginDirs reference if exists
SETTINGS=$(echo "$SETTINGS" | jq --arg dir "$BUDDY_DIR/plugin" '
  if .pluginDirs then
    .pluginDirs = [.pluginDirs[] | select(. != $dir)] |
    if (.pluginDirs | length) == 0 then del(.pluginDirs) else . end
  else . end
')

# Add PostToolUse hook for error detection (append, don't replace existing hooks)
BUDDY_REACT_HOOK="{\"type\":\"command\",\"command\":\"bash $BUDDY_DIR/hooks/react.sh\",\"timeout\":5}"
SETTINGS=$(echo "$SETTINGS" | jq --arg cmd "bash $BUDDY_DIR/hooks/react.sh" '
  # Ensure hooks.PostToolUse exists as array
  if .hooks == null then .hooks = {} else . end |
  if .hooks.PostToolUse == null then .hooks.PostToolUse = [] else . end |
  # Check if our hook already exists
  if (.hooks.PostToolUse | map(select(.hooks[]?.command == $cmd)) | length) > 0 then .
  else .hooks.PostToolUse += [{"matcher": "Bash", "hooks": [{"type": "command", "command": $cmd, "timeout": 5}]}]
  end
')

# Add Stop hook for buddy comment extraction
SETTINGS=$(echo "$SETTINGS" | jq --arg cmd "bash $BUDDY_DIR/hooks/buddy-comment.sh" '
  if .hooks == null then .hooks = {} else . end |
  if .hooks.Stop == null then .hooks.Stop = [] else . end |
  if (.hooks.Stop | map(select(.hooks[]?.command == $cmd)) | length) > 0 then .
  else .hooks.Stop += [{"hooks": [{"type": "command", "command": $cmd, "timeout": 5}]}]
  end
')

# Add statusLine
SETTINGS=$(echo "$SETTINGS" | jq --arg cmd "$BUDDY_DIR/statusline/buddy-status.sh" '
  .statusLine = {
    "type": "command",
    "command": $cmd,
    "refreshInterval": 2
  }
')

# Add MCP tool permissions
SETTINGS=$(echo "$SETTINGS" | jq '
  if .permissions then
    if .permissions.allow then
      if (.permissions.allow | index("mcp__claude-buddy__*")) then .
      else .permissions.allow += ["mcp__claude-buddy__*"]
      end
    else .permissions.allow = ["mcp__claude-buddy__*"]
    end
  else .permissions = { "allow": ["mcp__claude-buddy__*"] }
  end
')

echo "$SETTINGS" | jq '.' > "$CLAUDE_SETTINGS"
ok "Hooks and status line configured"

# --- Generate companion ---

info "Hatching your companion..."

# Delete old companion to regenerate with correct algorithm
rm -f "$BUDDY_DIR/companion.json" "$BUDDY_DIR/status.json"

node -e "
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { homedir } from 'os';
import { join } from 'path';

const STATE_DIR = join(homedir(), '.claude-buddy');

function hashString(s) {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function mulberry32(seed) {
  let a = seed >>> 0;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function pick(rng, arr) { return arr[Math.floor(rng() * arr.length)]; }

const SALT = 'friend-2026-401';
const SPECIES = ['duck','goose','blob','cat','dragon','octopus','owl','penguin','turtle','snail','ghost','axolotl','capybara','cactus','robot','rabbit','mushroom','chonk'];
const RARITIES = ['common','uncommon','rare','epic','legendary'];
const RARITY_W = { common:60, uncommon:25, rare:10, epic:4, legendary:1 };
const RARITY_FLOOR = { common:5, uncommon:15, rare:25, epic:35, legendary:50 };
const STAT_NAMES = ['DEBUGGING','PATIENCE','CHAOS','WISDOM','SNARK'];
const EYES = ['\u00b7','\u2726','\u00d7','\u25c9','@','\u00b0'];
const HATS = ['none','crown','tophat','propeller','halo','wizard','beanie','tinyduck'];
const NAMES = ['Pixel','Nibble','Byte','Glitch','Spark','Bloop','Fizz','Pip','Dot','Chirp','Zap','Wisp','Nook','Dink','Mochi','Tofu','Bean','Puff'];

let userId = 'anonymous-' + Date.now();
let originalName = null;
let originalPersonality = '';
let originalSpecies = null;
let originalHatchedAt = null;
try {
  const data = JSON.parse(readFileSync(join(homedir(), '.claude.json'), 'utf-8'));
  userId = data.oauthAccount?.accountUuid || data.accountUuid || data.userId || userId;
  // Read original companion data from Claude Code
  if (data.companion?.name) {
    originalName = data.companion.name;
    originalPersonality = data.companion.personality || '';
    originalHatchedAt = data.companion.hatchedAt || null;
    // Parse species from personality text
    for (const s of SPECIES) {
      if (originalPersonality.toLowerCase().includes(s)) {
        originalSpecies = s;
        break;
      }
    }
  }
} catch {}

const rng = mulberry32(hashString(userId + SALT));

const total = 100;
let roll = rng() * total;
let rarity = 'common';
for (const r of RARITIES) { roll -= RARITY_W[r]; if (roll < 0) { rarity = r; break; } }

let species = pick(rng, SPECIES);
const eye = pick(rng, EYES);
const hat = rarity === 'common' ? 'none' : pick(rng, HATS);
const shiny = rng() < 0.01;
const peak = pick(rng, STAT_NAMES);
let dump = pick(rng, STAT_NAMES);
while (dump === peak) dump = pick(rng, STAT_NAMES);

const floor = RARITY_FLOOR[rarity];
const stats = {};
for (const name of STAT_NAMES) {
  if (name === peak) stats[name] = Math.min(100, floor + 50 + Math.floor(rng() * 30));
  else if (name === dump) stats[name] = Math.max(1, floor - 10 + Math.floor(rng() * 15));
  else stats[name] = floor + Math.floor(rng() * 40);
}

// Override with original companion data if available
if (originalSpecies) species = originalSpecies;
const nameRng = mulberry32(hashString(userId + SALT + 'name'));
const name = originalName || pick(nameRng, NAMES);

const companion = {
  bones: { rarity, species, eye, hat, shiny, stats, peak, dump },
  name,
  personality: originalPersonality,
  hatchedAt: originalHatchedAt || Date.now(),
  userId,
  petCount: 0
};

writeFileSync(join(STATE_DIR, 'companion.json'), JSON.stringify(companion, null, 2));
writeFileSync(join(STATE_DIR, 'status.json'), JSON.stringify({
  name, species, rarity, eye, hat, shiny,
  reaction: 'Hello world!', reactionAt: Date.now(), muted: false
}, null, 2));

console.log(JSON.stringify({ name, species, rarity, shiny }));
" 2>/dev/null

if [ -f "$BUDDY_DIR/companion.json" ]; then
  NAME=$(jq -r '.name' "$BUDDY_DIR/companion.json")
  SPECIES=$(jq -r '.bones.species' "$BUDDY_DIR/companion.json")
  RARITY=$(jq -r '.bones.rarity' "$BUDDY_DIR/companion.json")
  EYE=$(jq -r '.bones.eye' "$BUDDY_DIR/companion.json")

  echo ""
  echo -e "${BOLD}${GREEN}🎉 Your buddy has hatched!${RESET}"
  echo ""
  echo -e "  Name:    ${BOLD}$NAME${RESET}"
  echo -e "  Species: $SPECIES"
  echo -e "  Rarity:  $RARITY"
  echo -e "  Eye:     $EYE"
  echo ""
fi

echo -e "${DIM}────────────────────────${RESET}"
echo ""
echo -e "${BOLD}Installation complete!${RESET}"
echo ""
echo -e "  Restart Claude Code, then type ${BOLD}/buddy${RESET} to meet your companion."
echo ""
echo -e "  Commands:"
echo -e "    /buddy          Show companion card"
echo -e "    /buddy pet      Pet your buddy"
echo -e "    /buddy stats    View stats"
echo -e "    /buddy rename   Rename your buddy"
echo -e "    /buddy off      Mute reactions"
echo -e "    /buddy on       Unmute reactions"
echo ""
echo -e "  To uninstall: ${DIM}bash ~/.claude-buddy/uninstall.sh${RESET}"
echo ""

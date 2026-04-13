/**
 * ASCII art for all 18 buddy species — matches the original Claude Code buddy
 * Each species has 3 animation frames, each 5 lines, ~12 chars wide.
 * {E} is replaced with the eye character at render time.
 */

import type { Species, Eye, Hat, Rarity, StatName, BuddyBones } from "./engine.js";
import { RARITY_STARS, HAT_ART, STAT_NAMES } from "./engine.js";

// ─── Species art: 3 frames × 5 lines each ──────────────────────────────────

export const SPECIES_ART: Record<Species, string[][]> = {
  duck: [
    ["            ", "    __      ", "  <({E} )___  ", "   (  ._>   ", "    `--'    "],
    ["            ", "    __      ", "  <({E} )___  ", "   (  ._>   ", "    `--'~   "],
    ["            ", "    __      ", "  <({E} )___  ", "   (  .__>  ", "    `--'    "],
  ],
  goose: [
    ["            ", "     ({E}>    ", "     ||     ", "   _(__)_   ", "    ^^^^    "],
    ["            ", "    ({E}>     ", "     ||     ", "   _(__)_   ", "    ^^^^    "],
    ["            ", "     ({E}>>   ", "     ||     ", "   _(__)_   ", "    ^^^^    "],
  ],
  blob: [
    ["            ", "   .----.   ", "  ( {E}  {E} )  ", "  (      )  ", "   `----'   "],
    ["            ", "  .------.  ", " (  {E}  {E}  ) ", " (        ) ", "  `------'  "],
    ["            ", "    .--.    ", "   ({E}  {E})   ", "   (    )   ", "    `--'    "],
  ],
  cat: [
    ["            ", "   /\\_/\\    ", "  ( {E}   {E})  ", "  (  \u03c9  )   ", "  (\")_(\")   "],
    ["            ", "   /\\_/\\    ", "  ( {E}   {E})  ", "  (  \u03c9  )   ", "  (\")_(\")~  "],
    ["            ", "   /\\-/\\    ", "  ( {E}   {E})  ", "  (  \u03c9  )   ", "  (\")_(\")   "],
  ],
  dragon: [
    ["            ", "  /^\\  /^\\  ", " <  {E}  {E}  > ", " (   ~~   ) ", "  `-vvvv-'  "],
    ["            ", "  /^\\  /^\\  ", " <  {E}  {E}  > ", " (        ) ", "  `-vvvv-'  "],
    ["   ~    ~   ", "  /^\\  /^\\  ", " <  {E}  {E}  > ", " (   ~~   ) ", "  `-vvvv-'  "],
  ],
  octopus: [
    ["            ", "   .----.   ", "  ( {E}  {E} )  ", "  (______)  ", "  /\\/\\/\\/\\  "],
    ["            ", "   .----.   ", "  ( {E}  {E} )  ", "  (______)  ", "  \\/\\/\\/\\/  "],
    ["     o      ", "   .----.   ", "  ( {E}  {E} )  ", "  (______)  ", "  /\\/\\/\\/\\  "],
  ],
  owl: [
    ["            ", "   /\\  /\\   ", "  (({E})({E}))  ", "  (  ><  )  ", "   `----'   "],
    ["            ", "   /\\  /\\   ", "  (({E})({E}))  ", "  (  ><  )  ", "   .----.   "],
    ["            ", "   /\\  /\\   ", "  (({E})(-))  ", "  (  ><  )  ", "   `----'   "],
  ],
  penguin: [
    ["            ", "  .---.     ", "  ({E}>{E})     ", " /(   )\\    ", "  `---'     "],
    ["            ", "  .---.     ", "  ({E}>{E})     ", " |(   )|    ", "  `---'     "],
    ["  .---.     ", "  ({E}>{E})     ", " /(   )\\    ", "  `---'     ", "   ~ ~      "],
  ],
  turtle: [
    ["            ", "   _,--._   ", "  ( {E}  {E} )  ", " /[______]\\ ", "  ``    ``  "],
    ["            ", "   _,--._   ", "  ( {E}  {E} )  ", " /[______]\\ ", "   ``  ``   "],
    ["            ", "   _,--._   ", "  ( {E}  {E} )  ", " /[======]\\ ", "  ``    ``  "],
  ],
  snail: [
    ["            ", " {E}    .--.  ", "  \\  ( @ )  ", "   \\_`--'   ", "  ~~~~~~~   "],
    ["            ", "  {E}   .--.  ", "  |  ( @ )  ", "   \\_`--'   ", "  ~~~~~~~   "],
    ["            ", " {E}    .--.  ", "  \\  ( @  ) ", "   \\_`--'   ", "   ~~~~~~   "],
  ],
  ghost: [
    ["            ", "   .----.   ", "  / {E}  {E} \\  ", "  |      |  ", "  ~`~``~`~  "],
    ["            ", "   .----.   ", "  / {E}  {E} \\  ", "  |      |  ", "  `~`~~`~`  "],
    ["    ~  ~    ", "   .----.   ", "  / {E}  {E} \\  ", "  |      |  ", "  ~~`~~`~~  "],
  ],
  axolotl: [
    ["            ", "}~(______)~{", "}~({E} .. {E})~{", "  ( .--. )  ", "  (_/  \\_)  "],
    ["            ", "~}(______){~", "~}({E} .. {E}){~", "  ( .--. )  ", "  (_/  \\_)  "],
    ["            ", "}~(______)~{", "}~({E} .. {E})~{", "  (  --  )  ", "  ~_/  \\_~  "],
  ],
  capybara: [
    ["            ", "  n______n  ", " ( {E}    {E} ) ", " (   oo   ) ", "  `------'  "],
    ["            ", "  n______n  ", " ( {E}    {E} ) ", " (   Oo   ) ", "  `------'  "],
    ["    ~  ~    ", "  u______n  ", " ( {E}    {E} ) ", " (   oo   ) ", "  `------'  "],
  ],
  cactus: [
    ["            ", " n  ____  n ", " | |{E}  {E}| | ", " |_|    |_| ", "   |    |   "],
    ["            ", "    ____    ", " n |{E}  {E}| n ", " |_|    |_| ", "   |    |   "],
    [" n        n ", " |  ____  | ", " | |{E}  {E}| | ", " |_|    |_| ", "   |    |   "],
  ],
  robot: [
    ["            ", "   .[||].   ", "  [ {E}  {E} ]  ", "  [ ==== ]  ", "  `------'  "],
    ["            ", "   .[||].   ", "  [ {E}  {E} ]  ", "  [ -==- ]  ", "  `------'  "],
    ["     *      ", "   .[||].   ", "  [ {E}  {E} ]  ", "  [ ==== ]  ", "  `------'  "],
  ],
  rabbit: [
    ["            ", "   (\\__/)   ", "  ( {E}  {E} )  ", " =(  ..  )= ", "  (\")__(\")" ],
    ["            ", "   (|__/)   ", "  ( {E}  {E} )  ", " =(  ..  )= ", "  (\")__(\")" ],
    ["            ", "   (\\__/)   ", "  ( {E}  {E} )  ", " =( .  . )= ", "  (\")__(\")" ],
  ],
  mushroom: [
    ["            ", " .-o-OO-o-. ", "(__________)","   |{E}  {E}|   ", "   |____|   "],
    ["            ", " .-O-oo-O-. ", "(__________)","   |{E}  {E}|   ", "   |____|   "],
    ["   . o  .   ", " .-o-OO-o-. ", "(__________)","   |{E}  {E}|   ", "   |____|   "],
  ],
  chonk: [
    ["            ", "  /\\    /\\  ", " ( {E}    {E} ) ", " (   ..   ) ", "  `------'  "],
    ["            ", "  /\\    /|  ", " ( {E}    {E} ) ", " (   ..   ) ", "  `------'  "],
    ["            ", "  /\\    /\\  ", " ( {E}    {E} ) ", " (   ..   ) ", "  `------'~ "],
  ],
};

// ─── Rarity ANSI colors (RGB, matches Claude Code's design palette) ─────────

const RARITY_COLOR: Record<Rarity, string> = {
  common:    "\x1b[38;2;153;153;153m",
  uncommon:  "\x1b[38;2;78;186;101m",
  rare:      "\x1b[38;2;177;185;249m",
  epic:      "\x1b[38;2;175;135;255m",
  legendary: "\x1b[38;2;255;193;7m",
};

const SHINY_COLOR = "\x1b[93m";
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";
const NC = "\x1b[0m";

// ─── Render functions ───────────────────────────────────────────────────────

export function getArtFrame(species: Species, eye: Eye, frame: number = 0): string[] {
  const frames = SPECIES_ART[species];
  const f = frames[frame % frames.length];
  return f.map((line) => line.replace(/\{E\}/g, eye));
}

export function renderCompanionCard(
  bones: BuddyBones,
  name: string,
  personality: string,
  reaction?: string,
  frame: number = 0,
): string {
  const color = RARITY_COLOR[bones.rarity];
  const stars = RARITY_STARS[bones.rarity];
  const shiny = bones.shiny ? `${SHINY_COLOR}\u2728 ${NC}` : "";
  const art = getArtFrame(bones.species, bones.eye, frame);

  const hatLine = HAT_ART[bones.hat];
  if (hatLine && !art[0].trim()) {
    art[0] = hatLine;
  }

  const W = 40;
  const hr = "\u2500".repeat(W - 2);
  const lines: string[] = [];

  lines.push(`${color}\u256d${hr}\u256e${NC}`);

  for (const artLine of art) {
    if (!artLine.trim()) continue;
    const padded = artLine.padEnd(W - 4);
    lines.push(`${color}\u2502${NC}  ${padded}${color}\u2502${NC}`);
  }

  lines.push(`${color}\u251c${"\u254c".repeat(W - 2)}\u2524${NC}`);

  lines.push(`${color}\u2502${NC} ${BOLD}${name}${NC}  ${color}${stars}${NC}${"".padEnd(2)}${color}\u2502${NC}`);
  lines.push(`${color}\u2502${NC} ${shiny}${color}${BOLD}${bones.rarity.toUpperCase()}${NC} ${bones.species}${"".padEnd(2)}${color}\u2502${NC}`);

  const cosmeticLine = `eye: ${bones.eye}  hat: ${bones.hat}`;
  lines.push(`${color}\u2502${NC} ${DIM}${cosmeticLine}${NC}${"".padEnd(W - cosmeticLine.length - 4)}${color}\u2502${NC}`);

  lines.push(`${color}\u251c${"\u254c".repeat(W - 2)}\u2524${NC}`);

  for (const stat of STAT_NAMES) {
    const val = bones.stats[stat];
    const filled = Math.round(val / 10);
    const bar = "\u2588".repeat(filled) + "\u2591".repeat(10 - filled);
    const label = stat.slice(0, 3).padEnd(3);
    const marker = stat === bones.peak ? " \u25b2" : stat === bones.dump ? " \u25bc" : "  ";
    const valStr = String(val).padStart(3);
    lines.push(`${color}\u2502${NC} ${DIM}${label}${NC} ${bar} ${valStr}${marker} ${color}\u2502${NC}`);
  }

  if (reaction) {
    lines.push(`${color}\u251c${"\u254c".repeat(W - 2)}\u2524${NC}`);
    const maxMsg = W - 8;
    const msg = reaction.length > maxMsg ? reaction.slice(0, maxMsg - 1) + "\u2026" : reaction;
    lines.push(`${color}\u2502${NC}  \ud83d\udcac ${msg}${"".padEnd(Math.max(0, maxMsg - msg.length + 1))}${color}\u2502${NC}`);
  }

  if (personality) {
    lines.push(`${color}\u251c${"\u254c".repeat(W - 2)}\u2524${NC}`);
    const maxW = W - 6;
    const words = personality.split(" ");
    let line = "";
    for (const word of words) {
      if (line.length + word.length + 1 > maxW) {
        lines.push(`${color}\u2502${NC}  ${DIM}${line.padEnd(maxW)}${NC}${color}\u2502${NC}`);
        line = word;
      } else {
        line = line ? `${line} ${word}` : word;
      }
    }
    if (line) {
      lines.push(`${color}\u2502${NC}  ${DIM}${line.padEnd(maxW)}${NC}${color}\u2502${NC}`);
    }
  }

  lines.push(`${color}\u2570${hr}\u256f${NC}`);

  return lines.join("\n");
}

export function renderStatusLine(
  bones: BuddyBones,
  name: string,
  reaction?: string,
): string {
  const face = SPECIES_ART[bones.species][0][2]?.replace(/\{E\}/g, bones.eye).trim() || "(?)";
  const color = RARITY_COLOR[bones.rarity];
  const stars = RARITY_STARS[bones.rarity];
  const shiny = bones.shiny ? "\u2728" : "";
  const msg = reaction ? ` \u2502 "${reaction}"` : "";
  return `${color}${face}${NC} ${BOLD}${name}${NC} ${shiny}${color}${stars}${NC}${msg}`;
}

export function getRarityColor(rarity: Rarity): string {
  return RARITY_COLOR[rarity];
}

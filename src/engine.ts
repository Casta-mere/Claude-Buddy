/**
 * claude-buddy engine — deterministic companion generation
 * Matches Claude Code's original algorithm: wyhash → mulberry32 → species/stats
 */

import { readFileSync } from "fs";
import { homedir } from "os";
import { join } from "path";

export const SALT = "friend-2026-401";

export const SPECIES = [
  "duck", "goose", "blob", "cat", "dragon", "octopus", "owl", "penguin",
  "turtle", "snail", "ghost", "axolotl", "capybara", "cactus", "robot",
  "rabbit", "mushroom", "chonk",
] as const;

export type Species = (typeof SPECIES)[number];

export const RARITIES = ["common", "uncommon", "rare", "epic", "legendary"] as const;
export type Rarity = (typeof RARITIES)[number];

export const RARITY_WEIGHTS: Record<Rarity, number> = {
  common: 60, uncommon: 25, rare: 10, epic: 4, legendary: 1,
};

export const STAT_NAMES = ["DEBUGGING", "PATIENCE", "CHAOS", "WISDOM", "SNARK"] as const;
export type StatName = (typeof STAT_NAMES)[number];

export const RARITY_FLOOR: Record<Rarity, number> = {
  common: 5, uncommon: 15, rare: 25, epic: 35, legendary: 50,
};

export const EYES = ["\u00b7", "\u2726", "\u00d7", "\u25c9", "@", "\u00b0"] as const;
export type Eye = (typeof EYES)[number];

export const HATS = [
  "none", "crown", "tophat", "propeller", "halo", "wizard", "beanie", "tinyduck",
] as const;
export type Hat = (typeof HATS)[number];

export const HAT_ART: Record<Hat, string> = {
  none:      "",
  crown:     "   \\^^^/    ",
  tophat:    "   [___]    ",
  propeller: "    -+-     ",
  halo:      "   (   )    ",
  wizard:    "    /^\\     ",
  beanie:    "   (___)    ",
  tinyduck:  "    ,>      ",
};

export const RARITY_STARS: Record<Rarity, string> = {
  common: "\u2605",
  uncommon: "\u2605\u2605",
  rare: "\u2605\u2605\u2605",
  epic: "\u2605\u2605\u2605\u2605",
  legendary: "\u2605\u2605\u2605\u2605\u2605",
};

export interface BuddyStats {
  DEBUGGING: number;
  PATIENCE: number;
  CHAOS: number;
  WISDOM: number;
  SNARK: number;
}

export interface BuddyBones {
  rarity: Rarity;
  species: Species;
  eye: Eye;
  hat: Hat;
  shiny: boolean;
  stats: BuddyStats;
  peak: StatName;
  dump: StatName;
}

export interface Companion {
  bones: BuddyBones;
  name: string;
  personality: string;
  hatchedAt: number;
  userId: string;
  petCount: number;
}

// ─── Hash: FNV-1a (matches reference Node.js path) ──────────────────────────

export function hashString(s: string): number {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

// ─── PRNG: Mulberry32 ───────────────────────────────────────────────────────

export function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ─── Generation ─────────────────────────────────────────────────────────────

function pick<T>(rng: () => number, arr: readonly T[]): T {
  return arr[Math.floor(rng() * arr.length)];
}

function rollRarity(rng: () => number): Rarity {
  const total = Object.values(RARITY_WEIGHTS).reduce((a, b) => a + b, 0);
  let roll = rng() * total;
  for (const r of RARITIES) {
    roll -= RARITY_WEIGHTS[r];
    if (roll < 0) return r;
  }
  return "common";
}

export function generateBones(userId: string): BuddyBones {
  const rng = mulberry32(hashString(userId + SALT));

  const rarity = rollRarity(rng);
  const species = pick(rng, SPECIES);
  const eye = pick(rng, EYES);
  const hat = rarity === "common" ? "none" : pick(rng, HATS);
  const shiny = rng() < 0.01;

  const peak = pick(rng, STAT_NAMES);
  let dump = pick(rng, STAT_NAMES);
  while (dump === peak) dump = pick(rng, STAT_NAMES);

  const floor = RARITY_FLOOR[rarity];
  const stats = {} as BuddyStats;
  for (const name of STAT_NAMES) {
    if (name === peak) {
      stats[name] = Math.min(100, floor + 50 + Math.floor(rng() * 30));
    } else if (name === dump) {
      stats[name] = Math.max(1, floor - 10 + Math.floor(rng() * 15));
    } else {
      stats[name] = floor + Math.floor(rng() * 40);
    }
  }

  return { rarity, species, eye, hat, shiny, stats, peak, dump };
}

// ─── Account UUID ───────────────────────────────────────────────────────────

export function getAccountUuid(): string | null {
  try {
    const claudeJson = readFileSync(join(homedir(), ".claude.json"), "utf-8");
    const data = JSON.parse(claudeJson);
    return data.oauthAccount?.accountUuid || data.accountUuid || data.userId || null;
  } catch {
    return null;
  }
}

// ─── Original companion from Claude Code ────────────────────────────────────

export interface OriginalCompanion {
  name: string;
  species: Species | null;
  personality: string;
  hatchedAt: number;
}

export function getOriginalCompanion(): OriginalCompanion | null {
  try {
    const claudeJson = readFileSync(join(homedir(), ".claude.json"), "utf-8");
    const data = JSON.parse(claudeJson);
    if (!data.companion?.name) return null;

    // Parse species from personality text
    let species: Species | null = null;
    const personality: string = data.companion.personality || "";
    for (const s of SPECIES) {
      if (personality.toLowerCase().includes(s)) {
        species = s;
        break;
      }
    }

    return {
      name: data.companion.name,
      species,
      personality,
      hatchedAt: data.companion.hatchedAt || Date.now(),
    };
  } catch {
    return null;
  }
}

// ─── Default names ──────────────────────────────────────────────────────────

const FALLBACK_NAMES = [
  "Pixel", "Nibble", "Byte", "Glitch", "Spark", "Bloop", "Fizz", "Pip",
  "Dot", "Chirp", "Zap", "Wisp", "Nook", "Dink", "Mochi", "Tofu", "Bean", "Puff",
];

export function getDefaultName(rng: () => number): string {
  return pick(rng, FALLBACK_NAMES);
}

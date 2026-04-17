import { readFileSync, writeFileSync, mkdirSync, existsSync, renameSync } from "fs";
import { homedir } from "os";
import { join } from "path";
import type { Companion, BuddyBones } from "./engine.js";

const STATE_DIR = join(homedir(), ".claude-buddy");
const COMPANION_FILE = join(STATE_DIR, "companion.json");
const STATUS_FILE = join(STATE_DIR, "status.json");
const SESSIONS_DIR = join(STATE_DIR, "sessions");

export interface SessionReaction {
  session_id: string;
  reaction: string;
  reactionAt: number;
}

export interface StatusState {
  name: string;
  species: string;
  rarity: string;
  eye: string;
  hat: string;
  shiny: boolean;
  reaction: string;
  reactionAt: number;
  muted: boolean;
}

function ensureDir(): void {
  if (!existsSync(STATE_DIR)) {
    mkdirSync(STATE_DIR, { recursive: true });
  }
}

function atomicWrite(filePath: string, data: string): void {
  const tmp = filePath + ".tmp." + process.pid;
  writeFileSync(tmp, data, "utf-8");
  renameSync(tmp, filePath);
}

export function loadCompanion(): Companion | null {
  try {
    const raw = readFileSync(COMPANION_FILE, "utf-8");
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

export function saveCompanion(companion: Companion): void {
  ensureDir();
  atomicWrite(COMPANION_FILE, JSON.stringify(companion, null, 2));
}

export function createCompanion(
  bones: BuddyBones,
  name: string,
  userId: string,
): Companion {
  return {
    bones,
    name,
    personality: "",
    hatchedAt: Date.now(),
    userId,
    petCount: 0,
  };
}

export function loadStatus(): StatusState | null {
  try {
    const raw = readFileSync(STATUS_FILE, "utf-8");
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

export function saveStatus(status: StatusState): void {
  ensureDir();
  atomicWrite(STATUS_FILE, JSON.stringify(status, null, 2));
}

export function updateReaction(reaction: string): void {
  const status = loadStatus();
  if (status) {
    status.reaction = reaction;
    status.reactionAt = Date.now();
    saveStatus(status);
  }
}

function ensureSessionsDir(): void {
  if (!existsSync(SESSIONS_DIR)) {
    mkdirSync(SESSIONS_DIR, { recursive: true });
  }
}

export function saveSessionReaction(sessionId: string, reaction: string): void {
  ensureSessionsDir();
  const data: SessionReaction = { session_id: sessionId, reaction, reactionAt: Date.now() };
  atomicWrite(join(SESSIONS_DIR, `${sessionId}.json`), JSON.stringify(data, null, 2));
}

export function updateReactionWithSession(reaction: string, sessionId?: string): void {
  updateReaction(reaction);
  if (sessionId) saveSessionReaction(sessionId, reaction);
}

export function syncStatusFromCompanion(companion: Companion, reaction?: string): void {
  const current = loadStatus();
  const status: StatusState = {
    name: companion.name,
    species: companion.bones.species,
    rarity: companion.bones.rarity,
    eye: companion.bones.eye,
    hat: companion.bones.hat,
    shiny: companion.bones.shiny,
    reaction: reaction || current?.reaction || "",
    reactionAt: reaction ? Date.now() : current?.reactionAt || 0,
    muted: current?.muted || false,
  };
  saveStatus(status);
}

export function setMuted(muted: boolean): void {
  const status = loadStatus();
  if (status) {
    status.muted = muted;
    saveStatus(status);
  }
}

export function getStateDir(): string {
  return STATE_DIR;
}

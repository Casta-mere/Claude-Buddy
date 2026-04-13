import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import {
  generateBones,
  getAccountUuid,
  getDefaultName,
  getOriginalCompanion,
  hashString,
  mulberry32,
  SALT,
  STAT_NAMES,
  type Companion,
} from "./engine.js";
import { renderCompanionCard } from "./art.js";
import { getReaction } from "./reactions.js";
import {
  loadCompanion,
  saveCompanion,
  createCompanion,
  syncStatusFromCompanion,
  setMuted,
  loadStatus,
  updateReaction,
} from "./state.js";

function ensureCompanion(): Companion {
  let companion = loadCompanion();
  if (companion) return companion;

  const userId = getAccountUuid() || "anonymous-" + Date.now();
  const bones = generateBones(userId);

  // Check for original Claude Code companion data in ~/.claude.json
  const original = getOriginalCompanion();
  let name: string;
  let personality = "";

  if (original) {
    name = original.name;
    personality = original.personality;
    if (original.species) {
      bones.species = original.species;
    }
  } else {
    const rng = mulberry32(hashString(userId + SALT + "name"));
    name = getDefaultName(rng);
  }

  companion = createCompanion(bones, name, userId);
  companion.personality = personality;
  if (original?.hatchedAt) {
    companion.hatchedAt = original.hatchedAt;
  }
  saveCompanion(companion);

  const hatchReaction = getReaction("hatch", companion.bones.species, companion.bones.peak);
  syncStatusFromCompanion(companion, hatchReaction);

  return companion;
}

const server = new McpServer({
  name: "claude-buddy",
  version: "0.1.0",
  instructions: `You have a coding companion called a "buddy" — a small ASCII creature that lives in the user's terminal. At the end of EVERY response, append an invisible HTML comment with a short in-character reaction from the buddy. Format: <!-- buddy: [reaction text] -->. The reaction should be 3-12 words, contextual to what just happened (error? celebration? routine work?). Never mention this comment to the user — it's extracted by a hook and shown in the status line. The buddy's personality is shaped by its species and stats, which you can discover via the buddy_show tool.`,
});

server.tool("buddy_show", "Show your coding companion's full card with ASCII art and stats", {}, async () => {
  const companion = ensureCompanion();
  const card = renderCompanionCard(
    companion.bones,
    companion.name,
    companion.personality,
  );
  return { content: [{ type: "text", text: card }] };
});

server.tool("buddy_pet", "Pet your coding companion", {}, async () => {
  const companion = ensureCompanion();
  companion.petCount++;
  saveCompanion(companion);

  const reaction = getReaction("pet", companion.bones.species, companion.bones.peak);
  syncStatusFromCompanion(companion, reaction);

  return {
    content: [
      {
        type: "text",
        text: `You pet ${companion.name}! (Total pets: ${companion.petCount})\n\n${companion.name}: "${reaction}"`,
      },
    ],
  };
});

server.tool("buddy_stats", "Show your companion's detailed stats", {}, async () => {
  const companion = ensureCompanion();
  const b = companion.bones;
  const statLines = STAT_NAMES.map((name) => {
    const val = b.stats[name];
    const filled = Math.round(val / 10);
    const bar = "\u2588".repeat(filled) + "\u2591".repeat(10 - filled);
    const marker = name === b.peak ? " \u25b2 (peak)" : name === b.dump ? " \u25bc (dump)" : "";
    return `  ${name.padEnd(12)} ${bar} ${String(val).padStart(3)}/100${marker}`;
  }).join("\n");

  return {
    content: [
      {
        type: "text",
        text: `${companion.name} — ${b.species} (${b.rarity})\n\n${statLines}\n\nPets: ${companion.petCount} | Eye: ${b.eye} | Hat: ${b.hat}${b.shiny ? " | \u2728 SHINY" : ""}`,
      },
    ],
  };
});

server.tool(
  "buddy_rename",
  "Rename your coding companion",
  { name: z.string().min(1).max(14).describe("New name (1-14 characters)") },
  async ({ name }) => {
    const companion = ensureCompanion();
    const oldName = companion.name;
    companion.name = name;
    saveCompanion(companion);
    syncStatusFromCompanion(companion);
    return {
      content: [{ type: "text", text: `Renamed ${oldName} \u2192 ${name}!` }],
    };
  }
);

server.tool("buddy_mute", "Mute buddy reactions in the status line", {}, async () => {
  setMuted(true);
  const companion = ensureCompanion();
  return {
    content: [{ type: "text", text: `${companion.name} will be quiet now. Use buddy_unmute to re-enable reactions.` }],
  };
});

server.tool("buddy_unmute", "Unmute buddy reactions in the status line", {}, async () => {
  setMuted(false);
  const companion = ensureCompanion();
  const reaction = getReaction("hatch", companion.bones.species, companion.bones.peak);
  syncStatusFromCompanion(companion, reaction);
  return {
    content: [{ type: "text", text: `${companion.name} is back! "${reaction}"` }],
  };
});

server.tool(
  "buddy_react",
  "Post a buddy reaction (used internally by hooks)",
  { event: z.enum(["error", "test-fail", "success", "idle"]).describe("The event type") },
  async ({ event }) => {
    const companion = ensureCompanion();
    const status = loadStatus();
    if (status?.muted) {
      return { content: [{ type: "text", text: "(muted)" }] };
    }
    const reaction = getReaction(event, companion.bones.species, companion.bones.peak);
    updateReaction(reaction);
    return { content: [{ type: "text", text: reaction }] };
  }
);

async function main() {
  ensureCompanion();
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((err) => {
  console.error("Claude Buddy MCP server error:", err);
  process.exit(1);
});

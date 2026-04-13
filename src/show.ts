import { generateBones, getAccountUuid, getDefaultName, getOriginalCompanion, hashString, mulberry32, SALT } from "./engine.js";
import { renderCompanionCard } from "./art.js";
import { getReaction } from "./reactions.js";
import { loadCompanion, createCompanion, saveCompanion, syncStatusFromCompanion } from "./state.js";

const userId = getAccountUuid() || "demo-user-" + Date.now();
let companion = loadCompanion();

if (!companion) {
  const bones = generateBones(userId);
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
  console.log("\n\ud83e\udd5a Your buddy just hatched!\n");
}

const card = renderCompanionCard(
  companion.bones,
  companion.name,
  companion.personality,
);

console.log(card);
console.log(`\nHatched: ${new Date(companion.hatchedAt).toISOString()}`);
console.log(`Pets: ${companion.petCount}`);
console.log(`User ID: ${companion.userId}\n`);

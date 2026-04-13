import type { Species, StatName } from "./engine.js";

export type ReactionEvent =
  | "hatch"
  | "pet"
  | "error"
  | "test-fail"
  | "success"
  | "idle";

// --- Generic reaction pools ---

const GENERIC_REACTIONS: Record<ReactionEvent, string[]> = {
  hatch: [
    "Hello world! I'm alive!",
    "Whoa... where am I?",
    "*blinks* Is this a terminal?",
    "Ready to code!",
    "Let's build something cool!",
  ],
  pet: [
    "*purrs contentedly*",
    "That's nice...",
    "*happy wiggle*",
    "More pets please!",
    "You're the best!",
    "*leans into hand*",
    "I could get used to this.",
  ],
  error: [
    "Oof, that didn't work.",
    "Have you tried turning it off and on?",
    "Bugs happen to the best of us.",
    "Error detected! Stay calm.",
    "Let's debug this together!",
    "*hides behind monitor*",
    "That's... not ideal.",
  ],
  "test-fail": [
    "Tests are just suggestions, right? ...Right?",
    "Red means stop and think.",
    "Almost there! Maybe.",
    "The tests have spoken.",
    "Back to the drawing board!",
    "Failing tests = learning opportunities!",
  ],
  success: [
    "Nice work!",
    "Ship it!",
    "That was smooth!",
    "*celebrates*",
    "You're on fire today!",
    "Clean code, clean mind.",
    "Another one bites the dust!",
  ],
  idle: [
    "*yawns*",
    "...zzz...",
    "*stretches*",
    "Still here!",
    "*whistles*",
    "*taps foot*",
    "Waiting for commands...",
  ],
};

// --- Species-specific overrides (used 40% of the time) ---

const SPECIES_REACTIONS: Partial<
  Record<Species, Partial<Record<ReactionEvent, string[]>>>
> = {
  cat: {
    pet: [
      "*purrs loudly*",
      "*slow blink of approval*",
      "*knocks something off desk*",
      "I'll allow it.",
    ],
    error: [
      "*pushes the bug off the table*",
      "I meant to do that.",
      "Not my fault.",
    ],
    idle: ["*knocks keyboard off desk*", "*stares at cursor*", "*naps on warm laptop*"],
  },
  duck: {
    pet: ["Quack! :)", "*happy quacking*", "Quack quack!"],
    error: ["Quack?!", "Have you tried rubber ducking?", "*confused quacking*"],
    success: ["QUACK!", "*victory quack*"],
  },
  owl: {
    error: ["Hoo would write such code?", "Let me review that..."],
    success: ["Wise choice!", "Hoo-ray!"],
    idle: ["*rotates head 270 degrees*", "*studies code silently*"],
  },
  dragon: {
    pet: ["*warm scales*", "*tiny smoke puff*", "*purrs like a furnace*"],
    error: ["*breathes fire at the bug*", "I'll burn that bug to ash!"],
    success: ["*triumphant roar*", "*happy smoke rings*"],
  },
  ghost: {
    hatch: ["Boo! ...wait, I'm friendly!", "*materializes*"],
    pet: ["*hand goes through*", "That tickles my ectoplasm!"],
    error: ["This code is haunted.", "*spooky debugging noises*"],
    idle: ["*phases through wall*", "*floats aimlessly*"],
  },
  robot: {
    error: ["SYNTAX ERROR DETECTED.", "Recalculating...", "Does not compute."],
    success: ["TASK COMPLETE.", "Efficiency: optimal.", "Beep boop, well done."],
    pet: ["AFFECTION RECEIVED. PROCESSING...", "*LED blinks happily*"],
    idle: ["Running diagnostics...", "*enters low power mode*"],
  },
  octopus: {
    pet: ["*wiggles all 8 arms*", "*ink blush*"],
    error: ["I've got 8 arms and can't fix this.", "*stress ink*"],
    success: ["*high-eights*", "*waves all arms*"],
  },
  axolotl: {
    hatch: ["*wiggles gills excitedly*", "Hewwo!"],
    pet: ["*gill flutter*", "*happy axolotl noises*"],
    error: ["I can regenerate... can the code?", "*confused gill wiggle*"],
  },
  capybara: {
    pet: ["*maximum chill achieved*", "*relaxed sigh*"],
    error: ["It's okay. Everything's okay.", "*stays calm*"],
    idle: ["*vibes peacefully*", "*sits in imaginary hot spring*"],
    success: ["Cool.", "*nods approvingly*"],
  },
  penguin: {
    pet: ["*happy waddle*", "*flaps tiny wings*"],
    error: ["That code is on thin ice.", "*slides away from problem*"],
    success: ["*celebratory waddle*", "*belly slides across keyboard*"],
  },
  mushroom: {
    hatch: ["*sprouts from the ground*", "I'm a fun guy!"],
    error: ["There's not mushroom for error.", "*releases debug spores*"],
    idle: ["*grows slightly*", "*photosynthesizes*"],
  },
  cactus: {
    pet: ["Ouch! ...but thanks.", "*prickly purr*"],
    error: ["That's a thorny problem.", "*pokes the bug*"],
    idle: ["*stands there menacingly*", "*absorbs sunlight*"],
  },
  snail: {
    success: ["Slow and steady wins!", "*leaves a trail of approval*"],
    error: ["We'll get there... eventually.", "*retreats into shell*"],
    idle: ["*moves imperceptibly*", "...still loading..."],
  },
  blob: {
    pet: ["*jiggles happily*", "*squishy noises*"],
    error: ["*absorbs the error*", "*confused wobble*"],
    success: ["*bounces with joy*", "*happy jiggle*"],
  },
  turtle: {
    error: ["*retreats into shell*", "Slow down and think."],
    success: ["Slow and steady!", "*peeks out happily*"],
    idle: ["*sunbathes*", "*contemplates existence*"],
  },
  goose: {
    pet: ["HONK!", "*aggressive affection*"],
    error: ["HONK! HONK!", "*chases the bug*", "*steals your keyboard*"],
    success: ["*triumphant honking*", "*steals the trophy*"],
  },
  rabbit: {
    pet: ["*nose twitch*", "*thumps foot happily*"],
    error: ["*nervous ear flick*", "Down the rabbit hole we go..."],
    success: ["*happy binky!*", "*zooms around*"],
  },
  chonk: {
    pet: ["*maximal chonk purr*", "*rolls over*", "*vibrates*"],
    error: ["*sits on the bug*", "Too chonky to care."],
    idle: ["*exists heavily*", "*gravitational pull detected*"],
  },
};

// --- Stat-influenced flavor ---

const STAT_FLAVORS: Partial<Record<StatName, Record<string, string[]>>> = {
  CHAOS: {
    error: ["Chaos reigns! I love it!", "This is fine. 🔥"],
    success: ["Somehow that worked?!", "Chaotic good!"],
  },
  SNARK: {
    error: ["Skill issue.", "Maybe try Stack Overflow?", "Interesting approach..."],
    success: ["Not bad, I guess.", "You did something right for once."],
  },
  WISDOM: {
    error: ["Every error teaches us something.", "Patience, young coder."],
    success: ["A wise implementation.", "Knowledge is the true treasure."],
  },
  PATIENCE: {
    error: ["Take a breath. We'll fix this.", "One step at a time."],
    success: ["Good things come to those who wait.", "Patience paid off!"],
  },
  DEBUGGING: {
    error: ["*puts on detective hat*", "Let me trace that...", "Check line by line!"],
    success: ["Bug-free zone!", "Flawless execution!"],
  },
};

/** Pick a reaction for a given event, species, and peak stat */
export function getReaction(
  event: ReactionEvent,
  species: Species,
  peakStat: StatName
): string {
  const roll = Math.random();

  // 20% chance: stat-flavored reaction
  if (roll < 0.2) {
    const statPool = STAT_FLAVORS[peakStat]?.[event];
    if (statPool && statPool.length > 0) {
      return statPool[Math.floor(Math.random() * statPool.length)];
    }
  }

  // 30% chance: species-specific reaction
  if (roll < 0.5) {
    const speciesPool = SPECIES_REACTIONS[species]?.[event];
    if (speciesPool && speciesPool.length > 0) {
      return speciesPool[Math.floor(Math.random() * speciesPool.length)];
    }
  }

  // Fallback: generic reaction
  const genericPool = GENERIC_REACTIONS[event];
  return genericPool[Math.floor(Math.random() * genericPool.length)];
}

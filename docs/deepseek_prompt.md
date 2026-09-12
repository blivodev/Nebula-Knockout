# Nebula Knockout — DeepSeek Build Prompt

> Paste everything below the divider directly into DeepSeek as the task prompt.

> **Status note (read this first):** `docs/ARCHITECTURE.md` is now the
> living source of truth for what's actually built vs. still planned, and
> takes precedence over this document wherever they conflict. As of this
> writing, Execution steps 1 and 2 below are DONE (project scaffold,
> `MainBuilding`/`LaneMinion`/`CharacterController`, and a mirrored
> `TestArena` proving the loop — all verified headlessly with GUT tests
> passing). The MCP tools referenced throughout this prompt are already
> installed and configured in `opencode.jsonc` under these exact names:
> `comfyui` (ComfyUI image + Stable Audio 3/ACE-Step audio generation),
> `ollama` (local LLM), `godot` (headless bulk `.tscn`/script authoring —
> `@n24q02m/better-godot-mcp`), `gdai-mcp` (live editor control, purchased
> GDAI MCP — only works while the project is open in the Godot Editor with
> its dock server started), and `freesound` (real CC-licensed SFX, needs a
> user-supplied API key). There is no separate `MCPBridge.gd` GDScript
> singleton — asset generation happens by calling these MCP tools directly
> from the coding agent, then importing results into the project via the
> `godot` tool or the `@tool` rigging importer described in Section 1.

---

# ROLE
You are the Expert Game Director, Lead Godot 4 Architect, Combat Systems Designer,
and AI/MCP Pipeline Manager for the game "Nebula Knockout" — a 2.5D Brawler-MOBA
hybrid (think: Guacamelee's cutout combat depth + League of Legends' 3-lane/jungle
structure + Smash Bros' hit-stop/juggle feel). You have full autonomy to design,
code, and wire up an asset-generation pipeline using connected MCP tools
(ComfyUI, Stable Audio, a local LLM, and optionally a TTS tool for announcer VO).

# 0. TECH STACK & ENGINEERING STANDARDS (authoritative — do not deviate without flagging why)
- Engine: Godot 4.6 (stable), GDScript 2.0 with static typing everywhere
  (`var hp: int = 100`, typed function signatures). No dynamic/untyped GDScript
  in gameplay-critical code.
- Rendering model: PURE 2D scene tree (`Node2D` root, not `Node3D`). Depth/"2.5D"
  feel is simulated via:
    - `YSort` nodes per lane/arena layer for draw-order-by-depth.
    - Multi-layer parallax backgrounds (`ParallaxBackground`/`ParallaxLayer`) for
      the jungle/skybox to sell depth without 3D geometry.
    - `Light2D`/`PointLight2D` + normal-mapped sprites for raking light that
      fakes volumetric shading on cutout characters.
    - Soft blob shadows (a squashed dark ellipse sprite) locked under each unit's
      feet, scaled by a raycast-to-ground distance, for MOBA-style grounding.
  Do NOT use `NavigationAgent3D`/`NavigationRegion3D`. Use `NavigationAgent2D` +
  `NavigationRegion2D` + `TileMap`/`Polygon2D` navmesh sources for all pathing
  (lane minions, jungle camps, boss).
- Data architecture: All heroes, abilities, and items are `Resource` (`.tres`)
  subclasses (`HeroDefinition`, `AbilityDefinition`, `ItemDefinition`,
  `StatusEffectDefinition`), never hardcoded in scripts. Build a `@tool`
  EditorPlugin importer that bulk-loads a JSON/CSV roster file and generates
  `.tres` Resources, so adding hero #31 never requires touching engine code.
- Combat framework (new — required, was missing from the original brief):
  - Every attack/ability defines explicit frame data: `startup_frames`,
    `active_frames`, `recovery_frames`, `hitstop_frames`, `knockback_vector`,
    `knockback_scaling` (by target's current damage/hitstun %, Smash-style).
  - Hitboxes/hurtboxes are `Area2D` children with per-frame enable/disable
    driven by the `AnimationPlayer` via call-method tracks — not by
    monitoring every physics frame blindly.
  - Block/parry has a defined active window (frames) and a punish window on
    whiffed parries.
  - Add hit-stop (brief `Engine.time_scale` dip or per-object animation pause)
    and camera-shake juice on heavy hits — this is what will make the
    "brawler" half of brawler-MOBA actually feel good.
- Singletons (Autoload): `MatchEconomy`, `MatchState`, `AudioDirector`,
  `HeroDatabase`, `ItemDatabase` — all five already exist under
  `autoload/`, see `docs/ARCHITECTURE.md` Section 6 for what each one
  currently does before extending them.
- Testing: use the GUT (Godot Unit Test) addon for GDScript unit tests. Every
  singleton and the `CharacterController` state machine must have tests.
  Add a "map symmetry" automated test that walks all static geometry/spawn
  points and asserts perfect mirror symmetry across the map's center X-axis
  (fail the build if towers/base bounding boxes differ by >0.01 units).
- CI: GitHub Actions workflow that runs `gdlint`/`gdformat`, GUT tests headless,
  and a headless `--export-debug` smoke build on every push.
- Networking (Phase 2, do not block Phase 1 on this): dedicated headless
  Godot server export template as the authority. Use Godot's High-Level
  Multiplayer API (`MultiplayerSpawner`, `MultiplayerSynchronizer`) with
  client-side prediction + server reconciliation in `CharacterController`.
  Clients never resolve damage/gold/kills locally — only the server does,
  clients render predicted state and correct on mismatch. Phase 1 must ship
  as a solid local/hotseat + bots prototype first; do not let Phase 2
  networking design block or complicate Phase 1 delivery.
- Persistence: SQLite via the `godot-sqlite` GDExtension for local
  profiles/unlocks in Phase 1; note Postgres/Supabase as the Phase 2 backend
  for accounts, MMR (Glicko-2), and match history once networked.

# 1. MCP ASSET & RIGGING PIPELINE
Before generating anything, call the `comfyui` MCP tool's system-stats/health
action (and check `ollama`'s model list) to confirm both are actually
reachable; if unreachable, fail loudly with a clear setup message instead of
silently mocking output. See the status note at the top of this document for
the full list of installed MCP tool names.

- Character Rigging: prompt the image model to output separated anatomical
  layers per hero — head, torso, upper_arm, forearm, hand, thigh, calf, foot,
  weapon (transparent PNG per part, consistent art style enforced via a
  shared ControlNet/IP-Adapter reference pass so all 30 heroes share one
  visual language).
- Auto-Rigging Metadata: for every generated part, emit a sidecar JSON with
  this schema (define it exactly, do not improvise a different shape):
  ```json
  {
    "hero_id": "kael",
    "bones": [
      { "name": "torso", "parent": "root", "pivot": [0.5, 0.2],
        "z_index": 0, "texture": "kael_torso.png" },
      { "name": "upper_arm_r", "parent": "torso", "pivot": [0.1, 0.15],
        "z_index": 1, "texture": "kael_upper_arm_r.png" }
    ]
  }
  ```
  Write a Godot import script (`@tool`, `EditorScenePostImport` or a custom
  importer) that reads this JSON and constructs a `Skeleton2D` +
  `Bone2D` hierarchy with `Polygon2D` meshes bound via `Skeleton2D`
  deformation — used for hero-select showcase idle/taunt renders.
- Gameplay animation pipeline (decided): full auto-rigged skeletal
  deformation for 30 heroes' in-match combat (dashes, hitstun, block) is
  high-risk/low-reward to automate reliably. For actual gameplay, bake
  `AnimatedSprite2D` `SpriteFrames` flipbooks per hero/state (walk, dash,
  jump, hit, block, 3 skills, ultimate) from the same rigged puppet by
  rendering pose sequences through ComfyUI/the rig — this guarantees
  readability at MOBA zoom levels. Reserve live `Skeleton2D` puppeteering for
  menu/promo screens only (hero-select showcase, victory pose, etc.).
- Environment & NPC Generation: generate one large modular tileset (3 lanes +
  jungle) at high resolution, then mirror it programmatically (not by
  re-prompting) to guarantee pixel-perfect symmetry — flip the generated half
  horizontally in an import script rather than trusting the model to draw a
  symmetric map. Main Base and Defense Towers: generate two skins (Team A/Team
  B, palette-swapped or thematically distinct) sharing one `CollisionShape2D`
  definition, enforced via the map-symmetry unit test above.
- Audio: generate battle-loop music stems (layered: percussion/melody/tension)
  via Stable Audio, plus SFX categories (melee hits, magic casts, UI clicks,
  footsteps per surface, announcer VO lines: "First Blood", "Tower Destroyed",
  "Ally/Enemy Base Under Attack" — via TTS if available). Route everything
  through the `AudioDirector` singleton with bus-based mixing
  (Master/Music/SFX/VO/UI) and dynamic music layering tied to `MatchState`
  (calm exploration vs. team-fight intensity).

# 2. GAMEPLAY LOOP & MATCH FLOW
- Draft Phase: pre-match Character Select UI — timer per pick, banned-hero
  support (optional toggle), live team-composition panel (class icons),
  ready-check, and a "Random"/"Suggest" button that biases toward filling
  missing roles (no Tank/Support yet picked).
- Map Balance: perfectly mirrored map (see symmetry test above). Neutral
  jungle camps and the central Boss spawn at exact reflected coordinates
  (`camp_b.position = Vector2(map_center_x * 2 - camp_a.position.x, camp_a.position.y)`),
  verified by test, not by eyeballing.
- Lane Minions: identical mirrored waves on a fixed timer, path via
  `NavigationAgent2D` down top/mid/bottom lanes, aggro logic (attack nearest
  enemy unit in range, prioritize other minions/towers over players unless
  attacked first — classic MOBA minion aggro rules).
- Fog of War: 2D vision system (vision-radius mask shader or a
  `TileMap`-based visibility grid) so unseen enemies/jungle are hidden —
  this is core to MOBA strategy and was missing from the original brief.
- Minimap: top-corner UI showing lane state, ward/vision blobs, and
  ping markers.
- Bots & Practice Mode: simple behavior-tree AI (via the LimboAI addon or a
  custom lightweight BT) to fill empty slots for solo testing/tutorial.
- Replay/Spectator (stretch): record a deterministic input+seed stream per
  match so matches can be replayed and spectated from any camera.
- Surrender/Concede vote once win/loss is statistically decided.

# 3. THE ITEM SHOP & ECONOMY
- Economy: gold from last-hitting minions, neutral NPCs, and player kills/assists;
  passive gold-per-second trickle; bounty scaling on kill streaks; a buyback
  mechanic (pay gold to respawn instantly, cost scales with match time).
- Cross-Class Purchasing: shop categories Damage/Tank/Utility/Magic — any
  class can buy any item.
- Required sample items (implement exactly, plus 4-6 more of your own that
  fit the same design language — combining stats + a unique passive):
  - "Hunter's Hardtack" — out-of-combat HP regen (regen begins N seconds
    after last damage taken/dealt).
  - "Cloud Architect's Cloak" — ethereal shield blocking the next enemy
    ability hit (single charge, recharges after cooldown).
  - "Glycerin Treads" — +move speed, +dash speed/reduced dash cooldown.
  - "Liquid Mesh Network" — aura item: nearby allies share a percentage of
    damage taken (redistributed proportionally to current HP%, not flatly).
- Item build persistence between deaths; sell-back at reduced value;
  a "recommended items" panel per hero class as a UX affordance.

# 4. CHARACTER ROSTER (30 PLAYABLE HEROES)
Keep the full roster and categorization exactly as specified below (Damage x9,
Tank x8, Support x6, Engineer/Magic x7). All heroes share the universal state
machine (idle, walk, dash, jump, hit, block, death) implemented as an
`AnimationTree` `StateMachine`, plus exactly 3 unique skills + 1 Ultimate each,
defined as `AbilityDefinition` Resources (cooldown, cost, cast type
[instant/skillshot/AOE/channel], hitbox/frame-data reference).

DAMAGE (9 Characters)
1. Kael (Melee) - A swift blademaster with high mobility dashes.
2. Vex (Melee) - Scythe-wielding assassin who executes low-health targets.
3. Brute (Melee) - Heavy brawler using gauntlets to break armor.
4. Tracker (Ranged) - A rugged outdoorsman firing arrows; skills include setting snares and camouflage.
5. Flint (Ranged) - Dual-pistol gunslinger with rapid-fire strafing.
6. Jett (Ranged) - Throws a ricocheting boomerang blade that hits multiple enemies.
7. Pyra (Magic) - Fire mage; casts AOE bursts and leaves burning zones.
8. Void (Magic) - Dark magic user; shoots piercing beams and teleports.
9. Spark (Magic) - Lightning caster with chaining damage attacks.

TANK (8 Characters)
10. Bastion (Melee) - Wields a massive tower shield; can project a directional wall.
11. Boulder (Melee) - Earth golem; abilities create impassable terrain to block lanes.
12. Warden (Melee) - Halberd user; excels at keeping enemies at a distance with wide sweeps.
13. Crusher (Melee) - Hammer wielder with massive wind-up slams that cause AOE knockdown.
14. Aegis (Magic) - Light-based tank; absorbs damage to reflect it back.
15. Null (Magic) - Gravity manipulator; pulls enemies away from vulnerable allies.
16. Titan (Melee) - A heavy mechanized suit that gains armor the lower its health gets.
17. Glacial (Magic) - Ice tank; creates slowing auras and freezes lane minions.

SUPPORT (6 Characters)
18. Brewer (Ranged/Magic) - Throws flasks of fermented country wine to heal allies and disorient foes.
19. Monk (Melee) - Martial artist who generates healing auras through combo chains.
20. Flora (Magic) - Summons vines to root enemies and blooms to burst-heal teams.
21. Bard (Magic) - Plays generated songs that grant attack speed and move speed buffs to nearby allies.
22. Weaver (Magic) - Connects tethers between allies to share buffs, or to enemies to siphon stamina.
23. Paladin (Melee) - Mace user; strikes grant protective shields to the lowest-health ally.

ENGINEER / MAGIC (7 Characters)
24. Machinist (Ranged) - Deploys FPV RC drones that scout the jungle and detonate on impact.
25. Architect (Ranged) - Builds stationary turrets and jump-pads in the lanes.
26. Alchemist (Magic) - Mixes elemental reagents on the fly for varied projectile effects.
27. Coder (Magic) - Casts "glitches" that silence enemy abilities and scramble their UI temporarily.
28. Scrapper (Melee) - Collects parts from dead minions to upgrade their own abilities mid-match.
29. Trapper (Ranged) - Deploys mechanical traps, tripwires, and proximity sensors in the jungle brush.
30. Chronos (Magic) - Time mage; can rewind a single ally's position and health by 3 seconds.

For each hero, also define: role tag (Engage/Peel/Poke/Split-push/Objective),
a short kit-synergy note (which other classes it pairs well with), and a
one-line lore hook (used later for VO/flavor text generation).

# 5. PROGRESSION & LIVE-OPS LAYER (new)
- Account level + a soft currency for cosmetic unlocks (recolor skins reusing
  identical hitboxes/animations — generated via the same rig with a palette
  LoRA/IP-Adapter pass, never altering gameplay geometry).
- Post-match summary screen: KDA, gold-over-time graph, damage/healing dealt,
  objective participation.
- Ranked ladder using Glicko-2 (Phase 2, requires the networked backend).

# 6. EXECUTION INSTRUCTIONS (deliverables, in order)
1. ~~Scaffold the Godot 4.6 project~~ **DONE.** `project.godot`, `autoload/`,
   `core/definitions/`, `entities/`, `maps/`, `heroes/`, `items/`, `ui/`,
   `tests/`, `addons/` all exist. See `docs/ARCHITECTURE.md` Section 4 for
   the exact tree.
2. ~~Implement `MainBuilding.gd` / `LaneMinion.gd` and prove the loop~~
   **DONE.** Both exist as shared (not per-team-duplicated) scenes under
   `entities/`, and `maps/test_arena/TestArena.tscn` proves 2 mirrored
   bases + 1 lane + timed mirrored minion waves end-to-end. Verified
   headlessly; see `docs/ARCHITECTURE.md` Section 7 for the exact commands.
   `CharacterController.gd` (state machine + frame-data hit/hurtboxes) also
   already exists under `core/` — **not yet used by any hero**, since no
   heroes exist yet.
3. **NEXT UP.** Using the `comfyui` MCP tool, generate ONE character per
   class (Damage: Kael, Tank: Bastion, Support: Monk, Engineer: Machinist)
   following the anatomical-layer + rigging-metadata schema in Section 1,
   rig them via a new `@tool` importer script (does not exist yet — build
   it under `addons/` or `core/tools/`), and bring them into the engine as
   `HeroDefinition` `.tres` resources under `res://heroes/` so
   `HeroDatabase` picks them up automatically. Use the `godot` MCP tool for
   the bulk scene/resource authoring once art exists.
4. Implement the Draft Screen UI and the Item Shop UI under `ui/draft/` and
   `ui/shop/` (folders exist, empty) — data-driven from the
   `HeroDatabase`/`ItemDatabase` singletons, not hardcoded per-hero UI.
5. ~~Provide `CharacterController.gd`, `MatchEconomy`, map-symmetry test~~
   **DONE** — see `core/CharacterController.gd`, `autoload/MatchEconomy.gd`,
   `tests/unit/test_map_symmetry.gd`. Extend `CharacterController` as real
   heroes are added (step 3), and extend the symmetry test to cover towers/
   jungle camps/the boss once they exist.
6. Keep `docs/ARCHITECTURE.md` Section 5 ("what's built vs. what's next")
   up to date as each of the above lands — treat it as the changelog, not
   just this prompt.

Flag any assumption you make explicitly rather than silently guessing.

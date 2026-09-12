# Nebula Knockout — Architecture & Project Status

This is the living source of truth for how the project is actually built,
as distinct from `docs/deepseek_prompt.md` (the original creative/technical
brief). Read this first; it records what's *already decided and built*, not
just what's planned.

## 1. Workflow: who does what

This repo is driven from opencode with a deliberate model split (see
`opencode.json` at repo root, and the user's global `opencode.jsonc`):

- **`plan` agent (Claude Sonnet 5)** — architecture decisions, reviewing
  diffs for correctness, writing/updating this document and the design
  prompt, resolving ambiguity, anything where a wrong call is expensive to
  unwind later.
- **`build` agent (DeepSeek)** — the actual implementation grind: writing
  GDScript, authoring `.tres` resources, building UI scenes, generating the
  30-hero roster content, wiring MCP asset-pipeline calls. Cheap and fast,
  which matters because most of the remaining work (30 heroes × art + kit +
  scenes) is repetitive, well-specified content production, not novel
  design.

Practical rule of thumb: if a task can be fully specified by pointing at
this document + `docs/deepseek_prompt.md` + an existing example (e.g. "add
hero #7 following the same pattern as hero #6"), it belongs to `build`. If
it requires making a new architectural call not already covered here, it
should go through `plan` first and get recorded back into this document.

## 2. MCP tool inventory (`opencode.jsonc`, project-scoped)

| Server | Package | Purpose | Status |
|---|---|---|---|
| `comfyui` | `comfyui-mcp` (npx) | 2D image generation (hero anatomical layers, environment tiles, ControlNet/IP-Adapter for style consistency) **and** audio generation (Stable Audio 3 / ACE-Step music+SFX, run as ComfyUI workflows) | Installed. Requires a local ComfyUI instance reachable at `127.0.0.1:8188`/`:8000` (auto-detected) or `COMFYUI_URL` set. |
| `ollama` | `ollama-mcp-server` (npx) | Local LLM for lore hooks, VO/flavor text, prompt rewriting | Installed. Requires `ollama serve` running locally. |
| `godot` | `@n24q02m/better-godot-mcp` (npx) | Headless authoring: `.tscn` scenes, GDScript, shaders, tilemaps, animation players/tracks, physics layers, audio buses, navigation, UI controls — directly on project files, no editor required | Installed, `GODOT_PROJECT_PATH` set to repo root. |
| `gdai-mcp` | GDAI MCP plugin v0.3.3 (purchased, `addons/gdai-mcp-plugin-godot/`) | Live Godot **editor** control: screenshots of editor/running game, runtime error + stack trace reading, arbitrary in-editor GDScript execution, play/stop scenes | Installed + enabled as an editor plugin. Only functions while the project is open in the Godot Editor with the GDAI MCP dock's server started. |
| `freesound` | `@mushan_bit/freesound-mcp` (npx) | Real, CC-licensed recorded SFX search/download, as a free/legal complement to AI-generated audio | Installed. Needs a free API key from freesound.org set as `FREESOUND_API_KEY` (placeholder currently empty — fill in before use). |

Deliberately **not** installed: any 3D generation/rigging tool (Meshy,
Blender MCP, etc.) — the game is pure 2D end-to-end (see Section 3), so
there is no 3D asset in the pipeline anywhere. PixelLab MCP (paid, does
real pixel-art auto-rigging/animation) was considered and rejected only
because it costs money and free/OSS was preferred; revisit if the
DIY rigging pipeline in Section 5 proves too labor-intensive.

`godot` (headless bulk authoring) and `gdai-mcp` (live editor debugging) are
complementary, not redundant: use `godot` to generate/modify the 30 heroes'
scenes and resources in bulk; use `gdai-mcp` when something is actually
broken at runtime and you need to see/read what the running game is doing.

## 3. Locked technical decisions

These override anything that conflicts in `docs/deepseek_prompt.md` (that
doc has been updated to match, but this is the canonical version):

- **Engine**: Godot 4.6 stable, typed GDScript everywhere.
- **Scene tree is pure 2D** (`Node2D`, not `Node3D`). "2.5D" is achieved by:
  - `YSort`/draw order per lane layer (not yet added to the test arena —
    needed once vertical sprite layering matters, i.e. once real hero art
    exists).
  - Parallax background layers for jungle/skybox depth.
  - `Light2D` + normal-mapped sprites for raking light (future, once art
    exists).
  - Blob shadows under units (future).
- **Navigation is 2D**: `NavigationRegion2D` / `NavigationAgent2D` / hand-
  built `NavigationPolygon`, never the 3D navigation nodes.
- **Physics layers** (`project.godot [layer_names]`):
  `1=team_a, 2=team_b, 3=neutral, 4=hitbox, 5=hurtbox, 6=structures`.
  Team-specific layer/mask bits are assigned **at runtime** in `_ready()`
  based on a `team` export var — every team-symmetric scene (minions,
  eventually heroes) is one shared scene, never a per-team duplicate.
- **Gameplay animation**: `AnimatedSprite2D`/`SpriteFrames` flipbooks drive
  actual combat (walk/dash/jump/hit/block/skills/ultimate). `Skeleton2D` +
  `Polygon2D` cutout rigs are reserved for hero-select/menu showcase
  puppeteering only — not live combat. (Decision recorded from the original
  planning conversation; full rationale in `docs/deepseek_prompt.md`
  Section 1.)
- **Networking**: none yet. Phase 1 (current) is local/hotseat + bots only.
  Phase 2 (not started) is a dedicated headless-server + Godot High-Level
  Multiplayer architecture with client prediction/server reconciliation —
  do not let it block Phase 1 work.
- **Data-driven everything**: heroes/abilities/items/status-effects are
  `Resource` subclasses under `core/definitions/`, instantiated as `.tres`
  files under `res://heroes/` and `res://items/`, auto-discovered by the
  `HeroDatabase`/`ItemDatabase` autoloads. Adding content should never
  require touching engine code.

## 4. Project structure (as built)

```
project.godot                  # autoloads, physics layers, enabled plugins
default_bus_layout.tres        # Master/Music/SFX/VO/UI audio buses

autoload/                      # singletons (see Section 6)
  MatchState.gd
  MatchEconomy.gd
  HeroDatabase.gd
  ItemDatabase.gd
  AudioDirector.gd

core/
  definitions/                 # Resource base classes, one .tres per instance later
    HeroDefinition.gd
    AbilityDefinition.gd
    ItemDefinition.gd
    StatusEffectDefinition.gd
  CharacterController.gd       # base class every playable hero extends

entities/
  main_building/MainBuilding.gd(+.tscn)   # one shared scene, both teams
  lane_minion/LaneMinion.gd(+.tscn)       # one shared scene, both teams
  projectile/Projectile.gd(+.tscn)        # generic SKILLSHOT projectile
  drone/ScoutDrone.gd(+.tscn)             # Machinist's drone
  bulwark_wall/BulwarkWall.gd(+.tscn)     # Bastion's temporary wall
  heroes/<hero>/<Hero>.tscn               # kael/bastion/monk/machinist/pyra
  heroes/<hero>/<Hero>Controller.gd       # bespoke ones; Pyra uses the base

scenes/
  GameRoot.gd(+.tscn)          # boot scene: Draft -> Match -> Post-match

statuses/
  burn.tres, slow.tres         # StatusEffectDefinition instances

maps/
  test_arena/TestArena.gd(+.tscn)  # proof-of-loop: mirrored bases + 1 lane
  hero_showcase/HeroShowcase.gd(+.tscn)   # renders all hero art in a row

art/heroes/<hero>.png          # transparent cutouts from the MCP pipeline
                               # (kael/bastion/monk/machinist) — see ART_STYLE.md

heroes/                        # 4x HeroDefinition .tres + 16x AbilityDefinition
                               # (kael/bastion/monk/machinist, one per class)
items/                         # empty — ItemDefinition .tres go here
ui/
  draft/                       # empty — Draft Screen UI goes here
  shop/                        # empty — Item Shop UI goes here

tests/unit/
  test_map_symmetry.gd         # GUT: verifies mirrored bases
  test_match_economy.gd        # GUT: last-hit gold, kill-streak bounty
  test_hero_rig_importer.gd    # GUT: rigging-metadata JSON -> Skeleton2D
  test_hero_database.gd        # GUT: 4 heroes load with complete kits
  test_hero_scenes.gd          # GUT: scenes load, have art + combat nodes

addons/
  gdai-mcp-plugin-godot/       # purchased plugin, extracted + enabled
  gut/                         # GUT 9.6.1, extracted + enabled
```

Also see **`docs/ART_STYLE.md`** — the authoritative visual style spec
(chibi HD-2D brawler), the working Z-Image Turbo ComfyUI workflow, and the
per-hero prompt template used to generate the current art.

## 5. What's built vs. what's next

**Built and verified** (headless `godot --headless --quit`, a 60-frame run
of the test arena, a run of the hero showcase, and
`godot ... -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
all pass clean — 61/61 tests, no script errors):

- Project scaffold, autoloads, physics layers, audio buses.
- `HeroDefinition` / `AbilityDefinition` / `ItemDefinition` /
  `StatusEffectDefinition` Resource schemas.
- `MatchState` (phase/timer/mirroring helper/buyback cost) and
  `MatchEconomy` (gold, last-hits, kill-streak bounty, buyback).
- `MainBuilding` (shared scene, destructible, emits win condition) and
  `LaneMinion` (shared scene, `NavigationAgent2D` pathing, aggro rules,
  last-hit payout) — both symmetric by construction.
- `TestArena`: two mirrored bases + one lane + timed mirrored minion waves,
  proving the core loop end-to-end.
- `CharacterController` base class: state machine (idle/walk/dash/jump/
  hit/block/casting/dead) with frame-data-driven hitbox activation and a
  hit-stop juice hook.
- **First four heroes, one per class, complete end-to-end**: Kael (Damage),
  Bastion (Tank), Monk (Support), Machinist (Engineer). Each has a
  `HeroDefinition` + 4 `AbilityDefinition` resources with real frame data,
  an art-wired scene under `entities/heroes/`, and a transparent PNG in
  `art/heroes/`. Each also has its own controller with real mechanics now:
  Kael (`KaelController`) Wind Slash + Phantom Dash + Riposte parry/counter;
  Bastion (`BastionController`) Shield Bash + Bulwark Wall (spawns a real
  blocking entity); Monk (`MonkController`) Flowing Palm + Serenity Step +
  Harmonic Convergence heals; Machinist (`MachinistController`) Scout Drone
  + Detonate + Recall + Drone Swarm (real drone entity with AOE detonation).
  Still data-only: Kael's multi-hit Thousand Cuts, Bastion's Guard Stance /
  Unbreakable, Monk's Chi Combo, and the drone's seeking behavior — each
  `.tres` description says so explicitly.
- **Working MCP art pipeline**: the `comfyui` MCP tool (Z-Image Turbo bf16
  + qwen_3_4b + the `z-image-ae` VAE) generated all five sprites, then
  BiRefNet (ComfyUI-RMBG) cut out the backgrounds. Style + prompt template
  are in `docs/ART_STYLE.md`.
- `HeroRigImporter` (`@tool`): parses rigging-metadata JSON into a
  `Skeleton2D` + `Bone2D` cutout rig for menu showcases (tested; not yet
  run against real per-limb art).
- **Items + shop**: 8 `ItemDefinition` resources, including the four
  required samples (Hunter's Hardtack, Cloud Architect's Cloak, Glycerin
  Treads, Liquid Mesh Network); a `PlayerInventory` autoload that aggregates
  item stat bonuses in one place; and a data-driven `ItemShop` UI
  (`ui/shop/`) with category tabs, a purchase flow, and gold/inventory
  wiring. Cross-class purchasing is unguarded by design.
- **Draft screen**: `DraftScreen` UI (`ui/draft/`) — roster grid with
  portraits, selected-hero detail panel, per-pick countdown with auto-lock,
  lock-in, a class-aware "Suggest", and a live team-composition display.
- **Playable arena slice**: `TestArena` now spawns the drafted hero
  (WASD to move, Q/E/R/F to cast), a `HUD` (`ui/hud/`: HP bar, gold, live
  skill-cooldown readout), and the `ItemShop`, toggled with **B**. Ability
  cooldowns are enforced in `CharacterController` (`is_on_cooldown()` /
  `get_cooldown_remaining()`), and attacks reach enemy minions / heroes /
  structures through team-configured physics layers (`_configure_combat_layers`),
  while never hitting allies. Minions aggro enemy heroes as well as minions
  and structures.
- **Status-effect system**: `StatusEffectDefinition` (data) + `ActiveStatus`
  (runtime) + apply/refresh/stack/expire/multiplier logic on
  `CharacterController`. Supports move-speed slows, damage-taken/dealt
  multipliers, and regen **or** damage-over-time (negative regen). Authored
  statuses live in `res://statuses/` (`burn`, `slow`).
- **Projectile system**: `Projectile` (`entities/projectile/`) fired
  automatically for any `cast_type == SKILLSHOT` ability from
  `CharacterController._spawn_projectile()`, with speed/range/pierce/color
  and an optional on-hit status. `cast_type == AOE` abilities are applied by
  `_apply_aoe()` over a radius. Both are generic, so ranged/mage heroes need
  **no custom controller** — just data.
- **Pyra** (5th hero, Damage/Magic fire mage): Ember Bolt (SKILLSHOT +
  burn), Flame Nova (AOE + burn), Cinder Field (wide AOE + burn), Inferno
  (ultimate AOE + burn). Uses the base `CharacterController` — pure data,
  proving the projectile/AOE path. Art generated via the same MCP pipeline.
- **Void** (6th hero, Damage/Magic cosmic dark mage): Void Beam (piercing
  SKILLSHOT), Nether Step (bespoke teleport blink in `VoidController`),
  Abyssal Rift (AOE slow), Event Horizon (ultimate AOE). Art generated via
  ComfyUI Z-Image Turbo + BiRefNet cutout.
- **Flint** (7th hero, Damage/Ranged dual-pistol gunslinger): Quick Shot (fast
  SKILLSHOT), Rapid Strafe (combat slide), Trick Shot (piercing SKILLSHOT),
  Bullet Storm (ultimate AOE). Pure data using the base `CharacterController`,
  following Pyra's no-code precedent. Art generated via ComfyUI Z-Image Turbo
  + BiRefNet cutout.
- **Vex** (8th hero, Damage/Melee scythe assassin): Scythe Sweep (INSTANT
  melee cleave), Shadow Dash (bespoke dash in `VexController`), Reaper's Mark
  (SKILLSHOT slow), Soul Reap (ultimate execution AOE). Art generated via
  ComfyUI Z-Image Turbo + BiRefNet cutout.
- **Knockback system**: `knockback_vector` and Smash-style `knockback_scaling`
  are now fully active and applied across melee attacks (`_apply_hit_to`),
  projectiles (`Projectile._hit`), and radial AOEs (`_apply_aoe`). Both
  `CharacterController` and `LaneMinion` receive knockback velocity and
  friction-decelerate in `_physics_process`.
- **Persistent GroundZones** (`cast_type == ZONE`): `entities/ground_zone/`
  spawns a zone at the caster's position that lives for `active_frames`,
  dealing `base_damage` every `zone_tick_sec` to enemies inside `radius` and
  re-applying `status_effect` per tick. Pyra's Cinder Field is now a true
  persistent burn zone, authored purely as data.
- **Multi-hit AOEs** (`multi_hit_ticks`): AOE abilities authored with
  `multi_hit_ticks > 0` split their damage into N pulses spread evenly
  across `active_frames` (Kael's Thousand Cuts: 6 pulses of 43.3). Pure data
  via the base `CharacterController` -- no bespoke hero code.
- **Bastion stances live**: Guard Stance (CHANNEL) = 50% damage reduction +
  25% reflect while active; Unbreakable (SELF) = 80% damage reduction + total
  knockback immunity. Both run through the generic frame-data timeline with
  damage math in `BastionController.take_damage`.
- **Monk Chi Combo live**: passive -- each Flowing Palm cast builds a Chi
  stack (max 3); a full stack empowers the next heal by +50% and is consumed.
- **Drone seeking live**: `ScoutDrone` steers toward the nearest living enemy
  hero/minion within its seek radius instead of flying blind.
- **BulwarkWall blocks enemies only**: per-team wall layers
  (`wall_blocks_team_a` layer 7 / `wall_blocks_team_b` layer 8); movers mask
  only the layer matching their own team, so allied walls are passable.
- **Resource (Mana/Energy) & Cast Range**: `AbilityDefinition.resource_cost` and
  `cast_range` are enforced in `cast_ability()`. Heroes have configurable
  `base_max_resource` and `base_resource_regen` in `HeroDefinition.gd`. In-match
  `HUD` displays a dedicated resource bar and surfaces `NO MANA` alerts.
- **Opponent Hero Bot**: `TestArena` spawns the drafted enemy hero on Team B
  (`spawn_enemy_hero`), driven by `_handle_bot_ai()` on `CharacterController`
  (`is_bot = true`). Bots acquire nearest targets, advance lanes, retreat at
  critical health, and cast abilities in range.
- **Animation**: `HeroAnimator` (`core/`) is added automatically to every
  hero's `Visual` node and gives procedural idle bob / walk sway / cast pop /
  hit flash / dash stretch / death squash, driven by the state machine. This
  is the stopgap until baked `SpriteFrames` flipbooks exist; it keeps working
  unchanged once the Visual becomes an `AnimatedSprite2D`.
- **Match flow**: `GameRoot` (`scenes/GameRoot.tscn`) is the boot scene
  (`project.godot` `run/main_scene`). It owns Draft -> Match -> Post-match
  -> Play Again: locking a hero spawns the arena with that hero, the enemy
  team is auto-filled, and base destruction shows a victory/defeat summary.
- **Draft screen**: hero grid, detail panel with portrait, per-pick countdown
  with auto-lock, Random/Suggest, LOCK IN, and a **START MATCH** button that
  skips the countdown entirely (auto-picks a suggested hero when nothing is
  selected). The status bar shows the loaded roster count so a
  HeroDatabase failure is visible, never a silent empty grid.
- **Export-safe resource listing**: `HeroDatabase` / `ItemDatabase` list their
  `res://` directories via `ResourceLoader.list_directory()` (with a
  `DirAccess` fallback for editor/older builds) -- `DirAccess` on `res://`
  only returns `.gd`/`.import` stubs inside an exported PCK, which silently
  emptied the roster and shop in exported builds.
- GUT suite (**95 tests across 15 scripts**, all green): map symmetry,
  economy, rig importer, hero database, hero scenes, items/inventory, shop,
  draft, hero mechanics, match flow, status effects, projectiles, knockback,
  resources and cast range, ground zones.

**Explicitly not built yet** (next work, suited to the `build`/DeepSeek
agent):

- The remaining 22 heroes (roster in `docs/deepseek_prompt.md` §4). The
  pattern is now fully established: 4 ability `.tres` + 1 hero `.tres` +
  1 scene + 1 art PNG; ranged/mage kits need no controller code at all.
- Audio (music/SFX) — `AudioDirector` + buses exist, nothing generated yet.
  The `musicgen` MCP server is now wired into `opencode.jsonc` (needs an
  opencode restart); `freesound` covers recorded SFX.
- Jungle camps, the neutral boss, towers (only a single lane + 2 bases
  exist in `TestArena`).
- Baked flipbook animation (`SpriteFrames`) per hero state — current art is
  static single-pose sprites and animation is procedural (`HeroAnimator`).
- Everything in "Phase 2" (networking, ranked/MMR, replays).

## 6. Autoload responsibilities (quick reference)

- **MatchState** — match phase enum, match timer, `mirror_position()`
  (the single source of truth for map symmetry — always mirror through
  this, never hand-place both sides), `buyback_cost()`.
- **MatchEconomy** — per-player gold ledger, passive income tick,
  last-hit/neutral-camp/kill/assist payouts, buyback spend.
- **HeroDatabase** — loads every `.tres` under `res://heroes/` at boot,
  lookup by id/class.
- **ItemDatabase** — same pattern for `res://items/`.
- **AudioDirector** — pooled SFX players + a music player with crossfade;
  this is what the MCP-generated/`freesound`-sourced audio ultimately plays
  through.

## 7. Running things yourself

```powershell
# Open in editor (also what starts the GDAI MCP dock server)
godot --path "D:\Projects\Nebula Knockout"

# Headless sanity check (no window, exits immediately)
godot --headless --quit --path "D:\Projects\Nebula Knockout"

# Run the proof-of-loop arena headlessly for N frames
godot --headless --path "D:\Projects\Nebula Knockout" res://maps/test_arena/TestArena.tscn --quit-after 60

# Run all unit tests
godot --headless --path "D:\Projects\Nebula Knockout" -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

First time opening in the editor after a fresh clone, run
`godot --headless --editor --quit --path "..."` once first — Godot needs to
build its global script-class cache before autoloads referencing
`class_name` types (like `HeroDefinition`) will resolve; skipping this step
produces spurious "Could not find type" parse errors on the very first run
only.

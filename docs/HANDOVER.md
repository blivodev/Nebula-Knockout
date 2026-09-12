# Nebula Knockout — Project Handover & Migration Document

> **Audience:** a new AI coding agent (Kilo Code in VS Code) picking up this
> project cold. Read this whole document before writing any code.
> **Repo root:** `D:\Projects\Nebula Knockout`
> **Last updated:** 2026-09-11
> **Companion docs:** `docs/ARCHITECTURE.md` (living status — treat as the
> source of truth), `docs/ART_STYLE.md` (visual style + asset pipeline),
> `docs/deepseek_prompt.md` (original full creative/technical brief).

---

## 0. TL;DR for the incoming agent

- This is a **Godot 4.6** 2.5D Brawler-MOBA hybrid, **typed GDScript**, pure
  2D scene tree. It runs, boots, and has **61 passing GUT unit tests**.
- **There are ZERO git commits.** Everything is untracked working-tree
  content. Your first action should be to make an initial commit so there is
  a safety net (see §5).
- The pattern for adding content is established and cheap: heroes are
  data-driven `.tres` resources; **ranged/mage heroes need no code at all**.
- Several MCP servers are configured for asset generation (ComfyUI, Godot,
  music, SFX). They live in `opencode.jsonc` today and must be re-declared in
  Kilo Code's `mcp_settings.json` (see §2).
- **Machine-specific absolute paths are hardcoded** in the MCP config and in
  `GODOT_PROJECT_PATH`. Fix these first if the machine differs (see §2.7).

---

## 1. Project Overview & Architecture

### 1.1 Purpose

"**Nebula Knockout**" is a competitive **2.5D brawler-MOBA hybrid**: a
3-lane/jungle MOBA economy and map structure (League-of-Legends-like) fused
with a side-on brawler combat feel (hit-stop, frame-data, juggle knockback).
Target roster is **30 heroes** across 4 classes (Damage / Tank / Support /
Engineer) with 3 skills + 1 ultimate each, plus items, a draft phase, and a
lane-minion/base economy.

Currently implemented as a **local/hotseat + bots prototype (Phase 1)**.
Networking is explicitly **Phase 2 and not started**.

### 1.2 Tech stack

| Concern | Choice |
|---|---|
| Engine | **Godot 4.6 stable** (`4.6.stable.official.89cea1439`) |
| Language | **GDScript 2.0**, statically typed (`var hp: int = 100`, typed signatures) |
| Rendering | **Pure 2D** (`Node2D`), *not* 3D. "2.5D" is faked via Y-sort intent, parallax, sprite scaling |
| Navigation | `NavigationRegion2D` / `NavigationAgent2D` / hand-built `NavigationPolygon` (never 3D nav) |
| Physics | `CharacterBody2D` + `Area2D` hitboxes; **6 named 2D physics layers** (see `project.godot`) |
| Testing | **GUT 9.6.1** (`addons/gut`), 61 tests, run headless |
| Data | Godot `Resource` subclasses authored as `.tres` files, auto-discovered by autoload databases |
| Audio | `AudioDirector` autoload + `default_bus_layout.tres` (Master/Music/SFX/VO/UI) |
| Editor plugins | `gdai-mcp-plugin-godot` (purchased live-editor MCP), `gut` |

### 1.3 Core architectural patterns (do not break these)

1. **Data-driven everything.** Heroes, abilities, items, and status effects
   are `Resource` subclasses under `core/definitions/`, instantiated as
   `.tres` under `res://heroes/`, `res://items/`, `res://statuses/`. The
   `HeroDatabase` / `ItemDatabase` autoloads scan those folders at boot.
   **Adding content must never require touching engine code.** Adding hero
   #31 = drop in 4 ability `.tres` + 1 hero `.tres` + 1 scene + 1 art PNG.
2. **One shared scene per symmetric entity.** `MainBuilding`, `LaneMinion`,
   and all hero scenes are single scenes used by *both* teams; the `team`
   export drives collision-layer bits and visuals at runtime in `_ready()`.
   Never duplicate a scene per team.
3. **Map symmetry by construction.** Never hand-place both sides of the map.
   Mirror through `MatchState.mirror_position()`. This is enforced by
   `tests/unit/test_map_symmetry.gd`.
4. **Frame-data combat.** Abilities declare `startup_frames` / `active_frames`
   / `recovery_frames` / `hitstop_frames` (in physics ticks). The base
   `CharacterController._process_ability_frames()` walks the timeline and
   toggles the hitbox / spawns the projectile / applies the AOE exactly during
   the active window. All frame counts are physics ticks, not render frames.
5. **Generic ability execution.** `cast_type == SKILLSHOT` ⇒ a `Projectile`
   is fired. `cast_type == AOE` ⇒ `_apply_aoe()` over `radius`. `cast_type ==
   INSTANT/SELF/CHANNEL` ⇒ melee hitbox or bespoke subclass logic. This is why
   Pyra (a mage) needs no controller code.
6. **Autoloads are the global state.** Six singletons, in load order:
   `MatchState`, `MatchEconomy`, `HeroDatabase`, `ItemDatabase`,
   `PlayerInventory`, `AudioDirector`. In Phase 2 only the dedicated server's
   copies would be authoritative.
7. **Singletons/behaviour are tested.** Every autoload and the hero state
   machine have GUT tests. Keep them green.

### 1.4 Directory map (essential files only)

```
project.godot                     # autoloads, physics layers, enabled plugins, main scene
default_bus_layout.tres           # Master/Music/SFX/VO/UI audio buses
opencode.jsonc                    # MCP server config for opencode (translate to Kilo, §2)

autoload/                         # global singletons (see §1.5)
  MatchState.gd        MatchEconomy.gd    HeroDatabase.gd
  ItemDatabase.gd      PlayerInventory.gd AudioDirector.gd

core/
  CharacterController.gd          # THE base class for every hero (state machine + combat + input)
  HeroAnimator.gd                 # procedural animation attached to each hero's Visual
  ActiveStatus.gd                 # runtime instance of a StatusEffectDefinition
  definitions/                    # Resource base classes
    HeroDefinition.gd  AbilityDefinition.gd  ItemDefinition.gd  StatusEffectDefinition.gd
  tools/
    HeroRigImporter.gd            # @tool: rigging-metadata JSON -> Skeleton2D/Bone2D cutout rig

entities/
  main_building/MainBuilding.gd(+.tscn)   # team base, destructible, win condition
  lane_minion/LaneMinion.gd(+.tscn)       # nav-path lane minion, aggro, last-hit gold
  projectile/Projectile.gd(+.tscn)        # generic SKILLSHOT projectile
  drone/ScoutDrone.gd(+.tscn)             # Machinist's drone entity
  bulwark_wall/BulwarkWall.gd(+.tscn)     # Bastion's temporary blocking wall
  heroes/kael/Kael.tscn + KaelController.gd
  heroes/bastion/Bastion.tscn + BastionController.gd
  heroes/monk/Monk.tscn + MonkController.gd
  heroes/machinist/Machinist.tscn + MachinistController.gd
  heroes/pyra/Pyra.tscn                   # NOTE: uses base CharacterController, no custom script

scenes/
  GameRoot.gd(+.tscn)             # BOOT SCENE: Draft -> Match -> Post-match -> Play Again

maps/
  test_arena/TestArena.gd(+.tscn)         # the actual playable arena (1 lane, 2 bases)
  hero_showcase/HeroShowcase.gd(+.tscn)   # renders all hero art in a row

ui/
  draft/DraftScreen.gd(+.tscn)    # character select
  shop/ItemShop.gd(+.tscn)        # item shop
  hud/HUD.gd(+.tscn)              # HP/gold/skill cooldowns

heroes/                           # 25 .tres: 5 HeroDefinitions + 20 AbilityDefinitions
items/                            # 8 ItemDefinition .tres
statuses/                         # burn.tres, slow.tres
art/heroes/                       # kael/bastion/monk/machinist/pyra .png (transparent cutouts)

tests/unit/                       # 12 GUT test scripts (61 tests)
addons/gut/                       # GUT 9.6.1
addons/gdai-mcp-plugin-godot/     # purchased GDAI live-editor MCP plugin (extracted)
gdai-mcp-plugin-godot_v0.3.3.zip  # original purchased plugin zip (backup; do NOT delete)

docs/
  ARCHITECTURE.md   ART_STYLE.md   deepseek_prompt.md   HANDOVER.md (this file)
```

### 1.5 Autoload API quick reference

**`MatchState`** — phase (`DRAFT`/`LOADING`/`IN_PROGRESS`/`POST_MATCH`),
`match_time_sec`, `team_a_picks`/`team_b_picks` (`Array[StringName]`),
`set_phase()`, `end_match(winning_team)`, `mirror_position(pos)`,
`buyback_cost()`. Signals: `phase_changed`, `match_ended`.

**`MatchEconomy`** — `register_player(id, starting_gold)`, `get_gold(id)`,
`add_gold`, `spend_gold`, `on_minion_last_hit`, `on_neutral_camp_cleared`,
`on_player_kill(killer, victim)`, `on_player_assist`, `try_buyback`. Passive
gold tick + kill-streak bounty. Signal: `gold_changed`.

**`HeroDatabase`** — `reload()`, `get_hero(id)`, `get_all_heroes()`,
`get_heroes_by_class(c)`, `count()`.

**`ItemDatabase`** — `reload()`, `get_item(id)`, `get_all_items()`,
`get_items_by_category(c)`, `count()`.

**`PlayerInventory`** — `get_items(player_id)`, `owns(player_id, item_id)`,
`add_item`, `remove_item`, `get_total_stats(player_id)` (sums `bonus_*`
fields across owned items), `clear_all()`. Signals: `item_added`,
`item_removed`.

**`AudioDirector`** — `play_sfx(stream, volume_db)`, `play_music(stream,
fade_sec)`, `stop_music(fade_sec)`. Pooled SFX players + music crossfade.

### 1.6 `CharacterController` public API (the class you'll extend most)

```
signals: state_changed(new_state), hit_landed(target, damage), died
enum State { IDLE, WALK, DASH, JUMP, HIT, BLOCK, CASTING, DEAD }
exports: hero_definition, team, player_id, is_player_controlled, visual_animation_enabled

cast_ability(ability) -> void          # starts the frame-data timeline; enforces cooldown
is_on_cooldown(ability) / get_cooldown_remaining(ability)
apply_status(def, source) / remove_status(id) / has_status(id)
get_status_count() / get_status_ids()
get_move_speed_multiplier() / get_damage_taken_multiplier() / get_damage_dealt_multiplier()
take_damage(amount, source)            # override to intercept (see KaelController parry)
heal(amount) / is_alive()
lowest_hp_ally(radius) / allies_in_radius(radius, include_self)
set_blocking(active)
_on_skill_pressed(slot)                # override per hero; base casts skill_1/2/3/ult on Q/E/R/F
```

Input (prototype): **WASD** move, **Q/E/R/F** cast skill_1/2/3/ultimate.
Direct key polling — **not** InputMap actions (deferred debt, see §4).

---

## 2. Model Context Protocol (MCP) Configuration & Tooling

### 2.1 Current state

Six MCP servers are declared in `opencode.jsonc` at the repo root. **Kilo Code
does not read `opencode.jsonc`** — you must re-declare them in Kilo's own MCP
config (§2.6). The declarations below are the source of truth.

| Server | Transport | Purpose | Required external process |
|---|---|---|---|
| `comfyui` | stdio (npx) | Image generation **and** audio (Stable Audio/ACE-Step) via ComfyUI | ComfyUI running (Desktop app) |
| `ollama` | stdio (npx) | Local LLM for text (lore, VO, prompt rewriting) | `ollama serve` |
| `godot` | stdio (npx) | Headless `.tscn`/GDScript/shader/tilemap/animation/physics/UI authoring | none (Godot binary auto-detected) |
| `gdai-mcp` | stdio (uv) | Live Godot **editor** control: screenshots, runtime errors, in-editor GDScript exec, play/stop | Godot Editor open **and** GDAI dock server started |
| `freesound` | stdio (npx) | Search/download real CC-licensed SFX | Freesound API key |
| `musicgen` | stdio (python) | Local Meta MusicGen music generation | its own venv + Python |

### 2.2 `comfyui` (image + audio generation) — the most important one

- **Package:** `comfyui-mcp` (artokun). Upstream is **unmaintained** as of
  this writing (favoring official Comfy-Org "Comfy MCP" at comfy.org/mcp),
  but it works today and is far more feature-complete than alternatives.
- **Command:** `npx -y comfyui-mcp`
- **Auto-detects** ComfyUI on `127.0.0.1:8188` or `:8000`. Set
  `COMFYUI_URL` in the server env if it runs elsewhere.
- **What we actually used it for on this project** (reproducible recipe in
  `docs/ART_STYLE.md`): Z-Image Turbo text-to-image → BiRefNet background
  removal → transparent hero PNGs in `art/heroes/`.
  - The ComfyUI install on the dev machine had **no checkpoints**. The
    working path was the Z-Image **separate-component** graph:
    `UNETLoader(z_image_turbo_bf16.safetensors)` +
    `CLIPLoader(qwen_3_4b.safetensors, type=qwen_image)` +
    `VAELoader(z-image-ae.safetensors)` + `TextEncodeZImageOmni` +
    `KSampler(dpmpp_sde/beta, 10 steps, cfg 1)` + `VAEDecode` + `SaveImage`.
  - `z-image-ae.safetensors` is **not** Flux's `ae.safetensors` despite the
    same architecture — keep them separate. It was downloaded from
    `Comfy-Org/z_image_turbo` → `split_files/vae/ae.safetensors`.
  - Background removal needs the **ComfyUI-RMBG** custom node (node
    `BiRefNetRMBG`, model `BiRefNet_toonout`), installed via
    `install_custom_node id: "comfyui-rmbg"`; **requires a ComfyUI restart**
    to load.
  - **Gotcha:** `restart_comfyui` via MCP took the server down for ~70 s
    before it came back. It does work; don't panic.

### 2.3 `ollama`

- **Package:** `ollama-mcp-server`
- **Command:** `npx -y ollama-mcp-server`
- **Env:** `OLLAMA_HOST=http://127.0.0.1:11434`
- **Models present on the dev machine:** `qwen2.5:3b`, `llama3.2:latest`
  (both support tool-calling), `gemma3:4b`, `gemma2:9b`.

### 2.4 `godot` (headless authoring) — free, safe, no external process

- **Package:** `@n24q02m/better-godot-mcp` (Apache-2.0, actively maintained,
  explicitly tested with opencode).
- **Command:** `npx -y @n24q02m/better-godot-mcp`
- **Env:** `GODOT_PROJECT_PATH=D:/Projects/Nebula Knockout` ← **machine-specific, verify/update**
- Provides 17 composite tools: `project`, `scenes`, `nodes`, `scripts`,
  `editor`, `config`, `resources`, `input_map`, `signals`, `animation`,
  `tilemap`, `shader`, `physics`, `audio`, `navigation`, `ui`, `help`.
- Works **without a running editor** (parses/edits `.tscn` text directly).

### 2.5 `gdai-mcp` (live editor) + `freesound` + `musicgen`

- **`gdai-mcp`** (purchased, v0.3.3): `uv run
  "D:/Projects/Nebula Knockout/addons/gdai-mcp-plugin-godot/gdai_mcp_server.py"`.
  Requires `uv` on PATH. **Only functions while the Godot Editor is open with
  the project AND the GDAI MCP dock's server started**; otherwise tool calls
  fail with a connection error (expected, not a config bug). Use it when you
  need to *see* the running game or read runtime errors; use `godot` for
  headless bulk edits.
- **`freesound`**: `npx -y @mushan_bit/freesound-mcp`, env
  `FREESOUND_API_KEY=...`. ⚠️ **The real key is currently in plaintext in
  `opencode.jsonc` (line ~81). Do not commit that to a public repo** — move
  it to an env var / secret before committing (see §4/§5).
- **`musicgen`**: `C:/Users/USER/mcp-servers/musicgen-mcp/venv/Scripts/python.exe
  C:/Users/USER/mcp-servers/musicgen-mcp/mcp_server.py` — **machine-specific
  absolute paths.** One tool: `generate_music(prompt, duration_seconds)` →
  path to a `.wav` in `~/Music/musicgen-mcp/`. CPU-only unless that venv's
  torch is a ROCm build (the dev box is ROCm).

### 2.6 How to configure these in Kilo Code (VS Code)

Kilo Code manages MCP servers through its **MCP Servers** panel, which writes
a `mcp_settings.json`. On Windows it is typically at:

```
%APPDATA%\Code\User\globalStorage\kilocode.kilo-code\settings\mcp_settings.json
```

(Use the Kilo Code UI's *Edit MCP Settings* button if your path differs —
don't guess the path; let the UI create the file, then paste the block below.)

Paste this into `mcp_settings.json` (Kilo/Roo schema — note `command` is a
string and args are a separate array, unlike opencode's single array):

```json
{
  "mcpServers": {
    "comfyui": {
      "command": "npx",
      "args": ["-y", "comfyui-mcp"],
      "env": {},
      "disabled": false,
      "alwaysAllow": []
    },
    "ollama": {
      "command": "npx",
      "args": ["-y", "ollama-mcp-server"],
      "env": { "OLLAMA_HOST": "http://127.0.0.1:11434" },
      "disabled": false,
      "alwaysAllow": []
    },
    "godot": {
      "command": "npx",
      "args": ["-y", "@n24q02m/better-godot-mcp"],
      "env": { "GODOT_PROJECT_PATH": "D:/Projects/Nebula Knockout" },
      "disabled": false,
      "alwaysAllow": []
    },
    "gdai-mcp": {
      "command": "uv",
      "args": ["run", "D:/Projects/Nebula Knockout/addons/gdai-mcp-plugin-godot/gdai_mcp_server.py"],
      "env": {},
      "disabled": false,
      "alwaysAllow": []
    },
    "freesound": {
      "command": "npx",
      "args": ["-y", "@mushan_bit/freesound-mcp"],
      "env": { "FREESOUND_API_KEY": "<paste-your-key-here>" },
      "disabled": false,
      "alwaysAllow": []
    },
    "musicgen": {
      "command": "C:/Users/USER/mcp-servers/musicgen-mcp/venv/Scripts/python.exe",
      "args": ["C:/Users/USER/mcp-servers/musicgen-mcp/mcp_server.py"],
      "env": {},
      "disabled": false,
      "alwaysAllow": []
    }
  }
}
```

**Prerequisites to verify before the servers will work:**

1. `node`/`npx` on PATH (Node ≥ 22 for comfyui-mcp).
2. `uv` on PATH (`uv --version`).
3. Godot 4.6 on PATH (or set the godot server's Godot path).
4. ComfyUI Desktop **running** (for `comfyui`).
5. `ollama serve` **running** (for `ollama`).
6. For `gdai-mcp`: open the project in the Godot Editor and start the GDAI
   MCP dock server.
7. For `musicgen`: the venv at the path above must exist.

### 2.7 Directive: how and when the new agent should use these tools

- **Always prefer `godot` (headless) for creating/editing scenes, resources,
  scripts, and UI.** It is free, fast, offline, and deterministic. This is
  your default authoring tool.
- **Use `gdai-mcp` only when you need runtime truth**: a screenshot of the
  running game, the actual runtime error/stack trace, or to execute ad-hoc
  GDScript in the live editor. Do not use it for bulk edits.
- **Use `comfyui` to generate new hero/environment art**, following
  `docs/ART_STYLE.md` exactly (same prompt template, Z-Image Turbo graph,
  BiRefNet cutout). Never invent a new art style. Save results to
  `art/heroes/<hero_id>.png`.
- **Use `musicgen` for music and `freesound` for recorded SFX**; wire both
  through the `AudioDirector` singleton (Music/SFX buses). Not done yet.
- **Use `ollama` for cheap text generation** (lore hooks, flavor text, VO
  lines) when filling out hero `.tres` metadata.
- **Verification rule:** after ANY code/scene change, run the headless test
  suite (§5) before declaring success. The project has a real regression
  suite; use it.

---

## 3. Current State & Progress

### 3.1 Completed and verified

- **Godot 4.6 project scaffold**: autoloads, 6 physics layers, audio bus
  layout, `run/main_scene = res://scenes/GameRoot.tscn`.
- **Data schemas**: `HeroDefinition`, `AbilityDefinition`, `ItemDefinition`,
  `StatusEffectDefinition`.
- **Autoloads**: `MatchState`, `MatchEconomy`, `HeroDatabase`,
  `ItemDatabase`, `PlayerInventory`, `AudioDirector`.
- **Core loop**: `MainBuilding` (destructible, emits win condition),
  `LaneMinion` (`NavigationAgent2D` pathing, aggro on minions/heroes/
  structures, last-hit gold), and `TestArena` (2 mirrored bases, 1 lane,
  timed mirrored minion waves).
- **`CharacterController`**: state machine, frame-data hitbox timing,
  ability cooldowns, player input, team-configured collision layers,
  status effects, projectile spawning, AOE application, hit-stop.
- **Status-effect system**: apply/refresh/stack/expire, move-speed /
  damage-taken / damage-dealt multipliers, regen and damage-over-time.
  Authored `statuses/burn.tres`, `statuses/slow.tres`.
- **Projectile system**: generic `Projectile` fired automatically for any
  `SKILLSHOT` ability; AOE applied over radius. Ranged/mage heroes need no
  code.
- **5 heroes** (of 30):
  - **Kael** (Damage/Melee) — Wind Slash, Phantom Dash, Riposte
    parry/counter, Thousand Cuts (ult, data-only).
  - **Bastion** (Tank/Melee) — Shield Bash, Bulwark Wall (spawns a real
    blocking entity), Guard Stance (data-only), Unbreakable (data-only).
  - **Monk** (Support/Melee) — Flowing Palm heal, Chi Combo (data-only),
    Serenity Step dash, Harmonic Convergence AOE heal.
  - **Machinist** (Engineer/Ranged) — Scout Drone, Detonate, Recall & Reload,
    Drone Swarm (real drone entity + AOE).
  - **Pyra** (Damage/Magic) — Ember Bolt (projectile+burn), Flame Nova (AOE),
    Cinder Field (wide AOE), Inferno (ult AOE). **No custom controller** —
    pure data, proving the generic ranged path.
- **Art pipeline**: all 5 hero sprites generated via MCP (Z-Image Turbo →
  BiRefNet cutout), saved transparent in `art/heroes/`, wired into scenes and
  `HeroDefinition.portrait`.
- **Items + shop**: 8 items (incl. the 4 required samples: Hunter's Hardtack,
  Cloud Architect's Cloak, Glycerin Treads, Liquid Mesh Network),
  `PlayerInventory`, data-driven `ItemShop` UI.
- **Draft screen** (`DraftScreen`): roster grid with portraits, detail panel,
  countdown with auto-lock, lock-in, class-aware Suggest, team composition.
- **HUD**: HP bar, gold, live skill-cooldown readout.
- **Match flow** (`GameRoot`): Draft → Match → Post-match → Play Again.
- **Animation**: `HeroAnimator` procedural idle/walk/cast/hit/dash/death on
  every hero's `Visual`.
- **`HeroRigImporter`** (`@tool`): rigging-metadata JSON → `Skeleton2D` +
  `Bone2D` cutout rig (tested; not yet run against real per-limb art).
- **Tests**: **61 GUT tests across 12 scripts**, all passing.

### 3.2 In progress / half-finished / stubbed

- **Per-hero data-only abilities** (defined with real numbers + frame data,
  but no bespoke behavior): Kael's **Thousand Cuts** (multi-hit), Bastion's
  **Guard Stance** and **Unbreakable** (need status-driven damage reduction /
  immunity), Monk's **Chi Combo** (stacking), Machinist's drone **seeking
  behavior**, Pyra's **Cinder Field** as a *persistent* ground zone. Each
  `.tres` description states this explicitly.
- **Enemy team is cosmetic.** `GameRoot._auto_pick_enemy()` fills
  `MatchState.team_b_picks`, but `TestArena` only spawns the *player* hero —
  there is no enemy hero in the arena.
- **Audio is entirely unwired.** `AudioDirector` + buses exist; zero assets.
- **Flipbook animation** not started (procedural only).
- **Jungle camps, neutral boss, towers** not started. `TestArena` is 1 lane.
- **`HeroRigImporter`** is untested against real per-limb art (only against
  procedurally-generated placeholder textures).
- **`CharacterController.DASH` state is effectively dead** — dashes set
  velocity but stay in `CASTING`; the animator's `DASH` branch never fires.
- **`JUMP` state is unused** (top-down 2D, no jump mechanic).

---

## 4. Pending Changes, Known Bugs & Regressions

### 4.1 Critical / process

- 🔴 **No git commits exist.** There is no safety net and no way to diff or
  revert. **Make an initial commit before changing anything** (see §5.4).
- 🔴 **Freesound API key is in plaintext in `opencode.jsonc`.** Do not push
  this to a public remote. Move it to an environment variable or a
  git-ignored secrets file, and consider rotating the key.
- 🟠 **Machine-specific absolute paths** in the MCP config
  (`GODOT_PROJECT_PATH`, the `gdai-mcp` script path, the `musicgen` venv
  path). These will be wrong on a different machine.

### 4.2 Known gameplay bugs / gaps (not yet fixed)

- **No resource/mana system.** `AbilityDefinition.resource_cost` is authored
  but **never enforced** — abilities only respect `cooldown_sec`.
- **`cast_range` is not enforced.** Abilities can be cast regardless of
  distance; only `projectile_max_range` and AOE `radius` have effect.
- **Knockback is not implemented.** `knockback_vector` and
  `knockback_scaling` are authored on many abilities but never applied to
  targets. This is a real gameplay gap.
- **`BulwarkWall` blocks BOTH teams.** A single `StaticBody2D` cannot
  selectively collide per team; making it enemy-only needs two bodies or a
  per-team layer scheme. Documented in `BulwarkWall.gd`.
- **Status `STACK_INDEPENDENTLY` is half-wired.** Multipliers intentionally
  ignore `stacks` (only periodic ticks scale), so stacking a slow does not
  compound. Intentional, but worth knowing.
- **Minion aggro is enter-only.** A minion acquires a target on
  `body_entered`/`area_entered` and drops it on exit; there is no periodic
  re-scan, and it will not chase a hero that attacked it from outside its
  aggro radius.
- **Last-hit gold attribution is narrow.** Only a `CharacterController`
  source credits gold. Kills by drones (non-`CharacterController`) or by
  other minions do not award last-hit gold.
- **Bastion's `take_damage` has no damage reduction** — Guard Stance /
  Unbreakable are inert.
- **`AudioDirector.play_music` crossfade** uses a `Tween` that is not
  awaited; rapid successive calls could interleave. Minor.

### 4.3 Technical debt / deferred refactoring

- **Input is direct key polling** (`Input.is_key_pressed(KEY_W)`, physical
  keycodes for Q/E/R/F), **not named InputMap actions**. Needed for
  remapping/controller support. `project.godot` has no `[input]` section.
- **`CharacterController` is large** (~380 lines) and mixes movement, combat,
  statuses, cooldowns, and animation setup. Consider splitting into
  components later, but **do not refactor without tests green**.
- **Hero scene `.tscn` files are hand-authored text** with duplicated
  structure (body shape + hurtbox + hitbox + Visual). A `@tool` hero-scene
  generator would remove the copy-paste as the roster grows.
- **`test_hero_database.gd` hardcodes the hero count (currently 5).** It will
  fail every time a hero is added until updated — expected, but remember it.
- **`test_hero_scenes.gd` hardcodes a hero→scene dict** and asserts
  `portrait != null`. Add new heroes there *only after* their portrait exists.
- **No CI.** `docs/deepseek_prompt.md` specifies a GitHub Actions workflow
  (gdlint/gdformat + GUT + headless export) that has not been created.
- **Godot class-cache first-run gotcha:** a fresh clone (no `.godot/`) will
  emit spurious "Could not find type" parse errors until you run the editor
  pass once. See §5.2.

### 4.4 Fixed recently (do not "re-fix")

- `PlayerInventory.get_items()` returned an untyped array against an
  `Array[ItemDefinition]` return type → fixed by building a typed array.
- `DraftScreen` declared `_team_a_label`/`_team_b_label` as `Label` but
  assigned `RichTextLabel`, which failed the **entire script parse** → fixed.
- `Projectile` outlived a freed caster and passed a dead `Node` into
  `take_damage` → now despawns when its caster is freed and null-guards the
  source.
- Double `move_and_slide()` during Kael's dash → removed the extra call.

---

## 5. Environment & Setup Instructions

### 5.1 Required software

| Tool | Version used | Notes |
|---|---|---|
| Godot | **4.6 stable** | `godot` on PATH (dev box: `C:\Users\USER\AppData\Local\Microsoft\WinGet\Links\godot.exe`) |
| Node.js / npx | Node ≥ 22 | for npx-based MCP servers |
| `uv` | 0.12.x | for the `gdai-mcp` server |
| ComfyUI | Desktop 0.34.6 | for `comfyui` MCP (image/audio gen) |
| Ollama | any | for `ollama` MCP |
| Python | 3.13 | for the `musicgen` venv |

### 5.2 ⚠️ First-run sequence (fresh clone / fresh `.godot`)

`.godot/` is git-ignored, so after cloning, **run the editor import pass
once** before running tests — Godot must build its global script-class cache,
or autoloads referencing `class_name` types will throw spurious "Could not
find type" errors:

```powershell
godot --headless --editor --quit --path "D:\Projects\Nebula Knockout"
```

### 5.3 Commands you will use constantly

```powershell
$proj = "D:\Projects\Nebula Knockout"

# 1) Rebuild class cache + import assets (run after adding new class_name or assets)
godot --headless --editor --quit --path $proj

# 2) Run the full unit test suite (61 tests) — MUST be green before you finish any task
godot --headless --path $proj -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit

# 3) Headless smoke run of the boot scene (GameRoot -> Draft), 120 frames
godot --headless --path $proj --quit-after 120

# 4) Run the arena directly (playable hero + HUD + minions), N frames
godot --headless --path $proj res://maps/test_arena/TestArena.tscn --quit-after 600

# 5) Render the hero showcase (all hero art in a row)
godot --headless --path $proj res://maps/hero_showcase/HeroShowcase.tscn --quit-after 60

# 6) Open the project in the editor (also what starts the GDAI MCP dock server)
godot --path $proj
```

Expected test output ends with `---- All tests passed! ----`. A parse error in
any script will surface here first.

### 5.4 Do this FIRST (safety net + secret hygiene)

1. **Rotate/relocate the Freesound key**: replace the literal in
   `opencode.jsonc` with a placeholder and load the real value from an
   environment variable or a git-ignored file.
2. **Make the initial commit** so there is a revert point:
   ```powershell
   git -C "D:\Projects\Nebula Knockout" add -A
   git -C "D:\Projects\Nebula Knockout" commit -m "Initial commit: Godot 4.6 MOBA prototype, 5 heroes, 61 GUT tests"
   ```
   (`.gitignore` already excludes `.godot/`, `.import/`, `export_presets.cfg`,
   `node_modules/`, OS cruft. `addons/` and `art/` **are** tracked
   intentionally.)

### 5.5 Environment variables

| Variable | Used by | Value |
|---|---|---|
| `GODOT_PROJECT_PATH` | `godot` MCP | `D:/Projects/Nebula Knockout` |
| `COMFYUI_URL` | `comfyui` MCP | unset (auto-detect) |
| `OLLAMA_HOST` | `ollama` MCP | `http://127.0.0.1:11434` |
| `FREESOUND_API_KEY` | `freesound` MCP | secret — do not hardcode |

---

## 6. Kickoff Prompt (copy/paste this as your first message to Kilo Code)

> **You are the Lead Godot Engineer for "Nebula Knockout"**, a 2.5D
> Brawler-MOBA hybrid built in **Godot 4.6 with typed GDScript**. The repo is
> at `D:\Projects\Nebula Knockout`. Read these three files fully before
> writing any code, in this order: **`docs/HANDOVER.md`** (this migration
> doc), **`docs/ARCHITECTURE.md`** (living status — authoritative), and
> **`docs/ART_STYLE.md`** (asset pipeline). Then skim
> **`docs/deepseek_prompt.md`** for the full 30-hero roster and design intent.
>
> **Ground rules (non-negotiable):**
> 1. The project is **data-driven**. Heroes/abilities/items/statuses are
>    `.tres` resources under `res://heroes/`, `res://items/`, `res://statuses/`,
>    auto-discovered by autoloads. Adding content must not require engine code.
>    Ranged/mage heroes need **no controller code** — `SKILLSHOT` abilities
>    auto-fire a `Projectile` and `AOE` abilities auto-apply over `radius` via
>    the base `CharacterController`.
> 2. **Never break the existing 61 GUT tests.** After every change run:
>    `godot --headless --path "D:\Projects\Nebula Knockout" -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
>    and confirm `---- All tests passed! ----`.
> 3. One shared scene per symmetric entity; set `team` at runtime. Mirror map
>    geometry via `MatchState.mirror_position()` only. Keep map symmetry tests
>    green.
> 4. Frame data is in **physics ticks**. Use the base timeline; don't
>    reimplement hitbox timing per hero.
> 5. `addons/gut/` and `addons/gdai-mcp-plugin-godot/` are required — do not
>    remove them. Keep `.uid` files.
> 6. Configure the MCP servers per **§2.6 of HANDOVER.md** in Kilo Code's
>    `mcp_settings.json` (comfyui, ollama, godot, gdai-mcp, freesound,
>    musicgen), and **fix any machine-specific paths** (`GODOT_PROJECT_PATH`,
>    the gdai-mcp script path, the musicgen venv path) to match this machine.
>
> **Your first task, in order:**
> 1. **Safety net + secrets first.** The repo currently has **zero commits**.
>    Before anything else: move the plaintext Freesound API key out of
>    `opencode.jsonc` into an environment variable (replace with a
>    placeholder), then create the initial git commit so there is a revert
>    point. Confirm `git log` shows it.
> 2. **Verify the baseline.** Run the editor import pass
>    (`godot --headless --editor --quit --path "D:\Projects\Nebula Knockout"`),
>    then the test suite. Confirm 61/61 pass. Report the exact output.
> 3. **Add the next two heroes** from the roster in `docs/deepseek_prompt.md`:
>    **Void** (Damage/Magic — piercing beam + teleport) and **Flint**
>    (Damage/Ranged — dual pistols, rapid strafe). Follow the exact pattern
>    Pyra established (she is the reference implementation for a no-code
>    projectile hero): author 4 `AbilityDefinition` `.tres` (Void's beam should
>    set `projectile_pierce = true`), 1 `HeroDefinition` `.tres` with
>    `scene_path`, a hero `.tscn` under `entities/heroes/<id>/`, generate art
>    via the `comfyui` MCP tool using the `docs/ART_STYLE.md` template and cut
>    out the background with BiRefNet, save to `art/heroes/<id>.png`, then set
>    `portrait`. Update `test_hero_database.gd` (count) and
>    `test_hero_scenes.gd` (dict) and add the heroes to
>    `maps/hero_showcase/HeroShowcase.gd`. Void's teleport is the one bespoke
>    mechanic — implement it in a `VoidController` only if the generic path
>    can't express it; otherwise keep it data-only and say so in the `.tres`
>    description.
> 4. **Then fix one known gap from HANDOVER.md §4.2 of your choosing**, most
>    valuably **knockback** (authored on many abilities but never applied) or
>    **`resource_cost`/`cast_range` enforcement**. Add GUT tests for whatever
>    you implement.
>
> Work incrementally, run the test suite after each step, and keep
> `docs/ARCHITECTURE.md` §5 ("What's built vs. what's next") updated as you
> go — it is the project's changelog. If you must make an architectural
> decision that isn't already covered in `ARCHITECTURE.md`, state it
> explicitly and record it there.

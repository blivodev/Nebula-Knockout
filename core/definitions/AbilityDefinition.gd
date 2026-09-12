class_name AbilityDefinition
extends Resource
## Data-driven ability definition (see docs/ARCHITECTURE.md, Combat
## Framework). Every hero skill/ultimate is one of these .tres resources --
## never hardcoded per-hero script logic for numbers/timing.

enum CastType { INSTANT, SKILLSHOT, AOE, CHANNEL, SELF, ZONE }

@export var ability_id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Cost & Cooldown")
@export var cooldown_sec: float = 1.0
@export var resource_cost: float = 0.0

@export_group("Cast")
@export var cast_type: CastType = CastType.INSTANT
@export var cast_range: float = 0.0
@export var radius: float = 0.0

@export_group("Frame Data")
## All frame counts are in physics ticks (Engine.physics_ticks_per_second),
## not render frames, so timing is independent of display refresh rate.
@export var startup_frames: int = 0
@export var active_frames: int = 1
@export var recovery_frames: int = 0
@export var hitstop_frames: int = 0

@export_group("Damage & Knockback")
## When true, base_damage is an amount HEALED rather than dealt -- a
## dedicated flag rather than overloading base_damage's sign, so healing
## abilities (Monk's Flowing Palm, its ultimate, etc.) stay unambiguous.
@export var is_heal: bool = false
@export var base_damage: float = 0.0
@export var knockback_vector: Vector2 = Vector2.ZERO
@export var knockback_scaling: float = 0.0 ## Scales with target's current hitstun/damage %, Smash-style.

@export_group("Projectile (spawned when cast_type == SKILLSHOT)")
@export var projectile_speed: float = 700.0
@export var projectile_max_range: float = 600.0
## Piercing projectiles pass through every enemy they hit instead of
## despawning on the first (e.g. Void's beam).
@export var projectile_pierce: bool = false
@export var projectile_color: Color = Color(1.0, 0.8, 0.3)

@export_group("Persistent Zone (spawned when cast_type == ZONE)")
## The GroundZone lives for active_frames (converted to seconds) at the
## caster's position, dealing base_damage every zone_tick_sec to each enemy
## inside radius and re-applying status_effect per tick (e.g. Cinder Field).
@export var zone_tick_sec: float = 0.5

@export_group("Multi-Hit AOE")
## When > 0 and cast_type == AOE, the hit is split into this many pulses
## spread evenly across active_frames, each dealing base_damage / multi_hit_ticks
## (e.g. Kael's Thousand Cuts) -- pure data, no bespoke controller code.
@export var multi_hit_ticks: int = 0

@export_group("On-Hit Effect")
## Optional status applied to each enemy hit, whether from a projectile or an
## AOE burst (e.g. Pyra's burn).
@export var status_effect: StatusEffectDefinition

func total_duration_frames() -> int:
	return startup_frames + active_frames + recovery_frames

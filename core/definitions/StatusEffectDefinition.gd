class_name StatusEffectDefinition
extends Resource
## Data-driven buff/debuff (slows, shields, DoTs, auras). Referenced by
## AbilityDefinition and ItemDefinition passives rather than hardcoding
## effect logic per hero/item.

enum StackBehavior { REFRESH_DURATION, STACK_INDEPENDENTLY, IGNORE_NEW }

@export var effect_id: StringName
@export var display_name: String = ""
@export var duration_sec: float = 1.0
@export var tick_interval_sec: float = 0.0 ## 0 = no periodic tick (e.g. a plain shield).
@export var stack_behavior: StackBehavior = StackBehavior.REFRESH_DURATION
@export var max_stacks: int = 1

@export_group("Modifiers (multiplicative unless noted)")
@export var move_speed_mult: float = 1.0
@export var damage_taken_mult: float = 1.0
@export var damage_dealt_mult: float = 1.0
## Applied once per tick_interval_sec. Positive heals; NEGATIVE = damage over
## time (a burn/poison), applied without hitstun so DoT ticks don't stun-lock.
@export var hp_regen_per_tick: float = 0.0

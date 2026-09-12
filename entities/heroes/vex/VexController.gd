class_name VexController
extends CharacterController
## Vex: Scythe-wielding assassin hero.
## Executes Shadow Dash with forward momentum during its active window,
## while Scythe Sweep, Reaper's Mark, and Soul Reap run through the generic pipeline.

const SHADOW_DASH_ID: StringName = &"vex_shadow_dash"

func _process_ability_frames(delta: float) -> void:
	super._process_ability_frames(delta)
	if _active_ability != null and _active_ability.ability_id == SHADOW_DASH_ID and _ability_phase == "active":
		velocity = facing * dash_speed

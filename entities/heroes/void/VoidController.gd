class_name VoidController
extends CharacterController
## Void: Dark magic damage dealer with piercing beam and teleportation.
## Nether Step is a bespoke teleport mechanic implemented here, while
## Void Beam (piercing skillshot), Abyssal Rift (AOE slow), and Event Horizon
## (AOE ultimate) run through the generic CharacterController pipeline.

const NETHER_STEP_ID: StringName = &"void_nether_step"
const TELEPORT_DISTANCE: float = 220.0

var _teleported_this_cast: bool = false

func cast_nether_step() -> void:
	if hero_definition == null or state == State.DEAD or state == State.CASTING:
		return
	cast_ability(hero_definition.skill_2)

func _process_ability_frames(delta: float) -> void:
	super._process_ability_frames(delta)
	if _active_ability == null:
		_teleported_this_cast = false
		return
	if _active_ability.ability_id == NETHER_STEP_ID:
		if _ability_phase == "active" and not _teleported_this_cast:
			_teleported_this_cast = true
			var dir: Vector2 = facing if facing.length_squared() > 0.01 else Vector2.RIGHT
			global_position += dir * TELEPORT_DISTANCE
		elif _ability_phase == "startup":
			_teleported_this_cast = false

func _on_skill_pressed(slot: int) -> void:
	if hero_definition == null:
		return
	match slot:
		0:
			cast_ability(hero_definition.skill_1)
		1:
			cast_nether_step()
		2:
			cast_ability(hero_definition.skill_3)
		3:
			cast_ability(hero_definition.ultimate)

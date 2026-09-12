class_name KaelController
extends CharacterController
## First fully wired proof-of-concept hero. Two of Kael's four abilities
## have real gameplay behavior:
##  - Wind Slash uses the base class's generic frame-data hitbox timing
##    completely unmodified -- proof that the generic framework is enough
##    for a plain damaging melee skillshot.
##  - Phantom Dash needs bespoke movement the generic base class doesn't
##    provide (it only toggles a hitbox on/off; it never moves the
##    character), so it's implemented here.
## Riposte and the Thousand Cuts ultimate are fully data-specified
## (res://heroes/kael_riposte.tres, res://heroes/kael_thousand_cuts.tres)
## but their bespoke behavior (parry/counter, multi-hit AOE) is not yet
## implemented -- see docs/ARCHITECTURE.md Section 5.

const PHANTOM_DASH_ID: StringName = &"kael_phantom_dash"
const RIPOSTE_ID: StringName = &"kael_riposte"

var _dash_direction: Vector2 = Vector2.RIGHT

func cast_skill_1() -> void:
	if hero_definition == null:
		return
	cast_ability(hero_definition.skill_1) # Wind Slash

func cast_skill_2(direction: Vector2) -> void:
	if hero_definition == null or state == State.DEAD or state == State.CASTING:
		return
	_dash_direction = direction.normalized() if direction.length() > 0.01 else Vector2.RIGHT
	cast_ability(hero_definition.skill_2) # Phantom Dash

func _process_ability_frames(delta: float) -> void:
	super._process_ability_frames(delta)
	if _active_ability == null:
		return
	if _active_ability.ability_id == PHANTOM_DASH_ID and _ability_phase == "active":
		# Only set velocity here; the base _physics_process calls
		# move_and_slide() once after this returns (calling it here too would
		# move twice per physics tick during the dash).
		velocity = _dash_direction * dash_speed
	elif _active_ability.ability_id == RIPOSTE_ID and hitbox != null:
		# Riposte is purely defensive -- its hitbox never deals damage.
		hitbox.monitoring = false

## Riposte parry: a hit taken during the parry window is fully negated, and
## the attacker is countered for the ability's damage value.
func take_damage(amount: float, source: Node = null) -> void:
	if _is_riposting() and source is CharacterController:
		var attacker := source as CharacterController
		if attacker.has_method("take_damage"):
			attacker.call("take_damage", _active_ability.base_damage, self)
		return # negate the incoming hit entirely
	super.take_damage(amount, source)

func _is_riposting() -> bool:
	return (
		_active_ability != null
		and _active_ability.ability_id == RIPOSTE_ID
		and _ability_phase == "active"
	)

## Local player input mapping for Kael's kit:
##   Q -> Wind Slash, E -> Phantom Dash (toward facing), R -> Riposte,
##   F -> Thousand Cuts.
func _on_skill_pressed(slot: int) -> void:
	if hero_definition == null:
		return
	match slot:
		0:
			cast_skill_1()
		1:
			cast_skill_2(facing)
		2:
			cast_ability(hero_definition.skill_3)
		3:
			cast_ability(hero_definition.ultimate)

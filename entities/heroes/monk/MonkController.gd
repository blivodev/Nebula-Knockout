class_name MonkController
extends CharacterController
## Monk: melee support healer. Real mechanics implemented here:
##   - Flowing Palm (Q): heals the lowest-HP living ally in range, or self.
##   - Serenity Step (R): a short repositioning dash.
##   - Harmonic Convergence (F): burst-heals every ally in a large radius.
## Chi Combo (E) stays data-only: stack tracking / empowered-heal is a
## follow-up (docs/ARCHITECTURE.md Section 5).

const SERENITY_STEP_ID: StringName = &"monk_serenity_step"

var _step_direction: Vector2 = Vector2.RIGHT

func _on_skill_pressed(slot: int) -> void:
	match slot:
		0:
			cast_skill_1() # Flowing Palm
		1:
			pass # Chi Combo is a passive; no active cast
		2:
			cast_serenity_step(facing)
		3:
			cast_ultimate()

func cast_skill_1() -> void:
	var ability: AbilityDefinition = hero_definition.skill_1 if hero_definition != null else null
	if not _can_cast(ability):
		return
	var target: CharacterController = lowest_hp_ally(ability.radius)
	if target == null:
		target = self
	target.heal(ability.base_damage)
	cast_ability(ability)

func cast_serenity_step(direction: Vector2) -> void:
	var ability: AbilityDefinition = hero_definition.skill_3 if hero_definition != null else null
	if not _can_cast(ability):
		return
	_step_direction = direction.normalized() if direction.length() > 0.01 else Vector2.RIGHT
	cast_ability(ability)

func cast_ultimate() -> void:
	var ability: AbilityDefinition = hero_definition.ultimate if hero_definition != null else null
	if not _can_cast(ability):
		return
	for ally in allies_in_radius(ability.radius, true):
		ally.heal(ability.base_damage)
	cast_ability(ability)

func _can_cast(ability: AbilityDefinition) -> bool:
	return (
		ability != null
		and state != State.DEAD
		and state != State.CASTING
		and not is_on_cooldown(ability)
	)

func _process_ability_frames(delta: float) -> void:
	super._process_ability_frames(delta)
	if _active_ability != null and _active_ability.ability_id == SERENITY_STEP_ID and _ability_phase == "active":
		velocity = _step_direction * dash_speed

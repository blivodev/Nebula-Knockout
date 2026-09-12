class_name MonkController
extends CharacterController
## Monk: melee support healer. Real mechanics implemented here:
##   - Flowing Palm (Q): heals the lowest-HP living ally in range, or self.
##   - Chi Combo (E): passive -- each Flowing Palm cast builds a Chi stack
##     (max 3); a full stack empowers the next Flowing Palm by +50% and is
##     consumed.
##   - Serenity Step (R): a short repositioning dash.
##   - Harmonic Convergence (F): burst-heals every ally in a large radius.

const SERENITY_STEP_ID: StringName = &"monk_serenity_step"
const CHI_MAX_STACKS: int = 3
const EMPOWERED_HEAL_MULT: float = 1.5

var _step_direction: Vector2 = Vector2.RIGHT
var _chi_stacks: int = 0

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

func get_chi_stacks() -> int:
	return _chi_stacks

func cast_skill_1() -> void:
	var ability: AbilityDefinition = hero_definition.skill_1 if hero_definition != null else null
	if not _can_cast(ability):
		return
	var target: CharacterController = lowest_hp_ally(ability.radius)
	if target == null:
		target = self
	var heal_amount: float = ability.base_damage
	if _chi_stacks >= CHI_MAX_STACKS:
		# Full Chi: the next heal is empowered and consumes the stacks.
		heal_amount *= EMPOWERED_HEAL_MULT
		_chi_stacks = 0
	else:
		_chi_stacks = mini(_chi_stacks + 1, CHI_MAX_STACKS)
	target.heal(heal_amount)
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

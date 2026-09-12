class_name BastionController
extends CharacterController
## Bastion: melee tank. Real mechanics:
##   - Shield Bash (Q): generic frame-data hitbox + knockback (no bespoke code).
##   - Bulwark Wall (E): spawns a temporary enemy-only blocking wall in front.
##   - Guard Stance (R): 50% damage reduction + 25% damage reflect while active.
##   - Unbreakable (F): 80% damage reduction + total knockback immunity while
##     active.
## Stances run through the generic CHANNEL/SELF frame-data timeline; the
## damage math lives in take_damage() below.

const BulwarkWallScene: PackedScene = preload("res://entities/bulwark_wall/BulwarkWall.tscn")
const WALL_SPAWN_DISTANCE: float = 80.0

const GUARD_STANCE_ID: StringName = &"bastion_guard_stance"
const UNBREAKABLE_ID: StringName = &"bastion_unbreakable"
const GUARD_STANCE_DAMAGE_MULT: float = 0.5 # take 50% damage while channeling
const GUARD_STANCE_REFLECT_FRACTION: float = 0.25 # reflect 25% of the raw hit
const UNBREAKABLE_DAMAGE_MULT: float = 0.2 # take 20% damage while shielded

func _on_skill_pressed(slot: int) -> void:
	match slot:
		0:
			cast_ability(hero_definition.skill_1) # Shield Bash
		1:
			cast_bulwark_wall()
		2:
			cast_ability(hero_definition.skill_3) # Guard Stance
		3:
			cast_ability(hero_definition.ultimate) # Unbreakable

func cast_bulwark_wall() -> void:
	var ability: AbilityDefinition = hero_definition.skill_2 if hero_definition != null else null
	if (
		ability == null
		or state == State.DEAD
		or state == State.CASTING
		or is_on_cooldown(ability)
	):
		return
	var wall: BulwarkWall = BulwarkWallScene.instantiate() as BulwarkWall
	wall.team = team
	wall.position = global_position + facing * WALL_SPAWN_DISTANCE
	# Orient the wall across the facing direction so it blocks passage.
	wall.rotation = facing.angle() + PI * 0.5
	get_parent().add_child(wall)
	cast_ability(ability)

## Stance damage math: Guard Stance halves incoming damage and reflects a
## quarter of the raw hit back at the attacker; Unbreakable cuts damage to
## 20% and nullifies knockback entirely. Reflected damage bypasses the
## attacker's own stance logic (flat take_damage call).
func take_damage(amount: float, source: Node = null, knockback: Vector2 = Vector2.ZERO) -> void:
	if _is_stancing(GUARD_STANCE_ID):
		var reflected: float = amount * GUARD_STANCE_REFLECT_FRACTION
		amount *= GUARD_STANCE_DAMAGE_MULT
		knockback *= GUARD_STANCE_DAMAGE_MULT
		if reflected > 0.0 and source is Node and source.has_method("take_damage"):
			source.call("take_damage", reflected, self, Vector2.ZERO)
		super.take_damage(amount, source, knockback)
		return
	if _is_stancing(UNBREAKABLE_ID):
		amount *= UNBREAKABLE_DAMAGE_MULT
		super.take_damage(amount, source, Vector2.ZERO) # full knockback immunity
		return
	super.take_damage(amount, source, knockback)

func _is_stancing(ability_id: StringName) -> bool:
	return (
		_active_ability != null
		and _active_ability.ability_id == ability_id
		and _ability_phase == "active"
	)

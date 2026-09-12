class_name BastionController
extends CharacterController
## Bastion: melee tank. Real mechanics:
##   - Shield Bash (Q): generic frame-data hitbox + knockback (no bespoke code).
##   - Bulwark Wall (E): spawns a temporary blocking wall in front of Bastion.
## Guard Stance (R) and Unbreakable (F) remain data-only (damage-reduction /
## immunity statuses need the status-effect system, docs/ARCHITECTURE.md §5).

const BulwarkWallScene: PackedScene = preload("res://entities/bulwark_wall/BulwarkWall.tscn")
const WALL_SPAWN_DISTANCE: float = 80.0

func _on_skill_pressed(slot: int) -> void:
	match slot:
		0:
			cast_ability(hero_definition.skill_1) # Shield Bash
		1:
			cast_bulwark_wall()
		2:
			pass # Guard Stance -- data-only for now
		3:
			pass # Unbreakable -- data-only for now

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

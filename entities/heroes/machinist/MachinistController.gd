class_name MachinistController
extends CharacterController
## Machinist: ranged engineer. Real mechanics:
##   - Scout Drone (Q): deploys a forward-flying drone (one at a time).
##   - Detonate (E): blows up the active drone for an area burst.
##   - Recall & Reload (R): removes the active drone and refunds 5s of the
##     deploy cooldown.
##   - Drone Swarm (F): deploys three drones in a spread.

const ScoutDroneScene: PackedScene = preload("res://entities/drone/ScoutDrone.tscn")
const DEPLOY_OFFSET: float = 40.0
const RECALL_COOLDOWN_REFUND: float = 5.0

var _active_drone: ScoutDrone = null

func _on_skill_pressed(slot: int) -> void:
	match slot:
		0:
			deploy_drone()
		1:
			detonate_drone()
		2:
			recall_drone()
		3:
			cast_ultimate()

func deploy_drone() -> void:
	var ability: AbilityDefinition = hero_definition.skill_1 if hero_definition != null else null
	if not _can_act(ability):
		return
	if _active_drone != null and is_instance_valid(_active_drone):
		return # one active drone at a time
	_active_drone = ScoutDroneScene.instantiate() as ScoutDrone
	_active_drone.team = team
	_active_drone.direction = facing
	_active_drone.position = global_position + facing * DEPLOY_OFFSET
	get_parent().add_child(_active_drone)
	cast_ability(ability)

func detonate_drone() -> void:
	var ability: AbilityDefinition = hero_definition.skill_2 if hero_definition != null else null
	if ability == null or is_on_cooldown(ability):
		return
	if _active_drone == null or not is_instance_valid(_active_drone):
		return
	_active_drone.detonate()
	_active_drone = null
	cast_ability(ability)

func recall_drone() -> void:
	var ability: AbilityDefinition = hero_definition.skill_3 if hero_definition != null else null
	if ability == null or is_on_cooldown(ability):
		return
	if _active_drone != null and is_instance_valid(_active_drone):
		_active_drone.queue_free()
		_active_drone = null
	var deploy: AbilityDefinition = hero_definition.skill_1 if hero_definition != null else null
	if deploy != null:
		_cooldowns[deploy.ability_id] = maxf(0.0, get_cooldown_remaining(deploy) - RECALL_COOLDOWN_REFUND)
	cast_ability(ability)

func cast_ultimate() -> void:
	var ability: AbilityDefinition = hero_definition.ultimate if hero_definition != null else null
	if not _can_act(ability):
		return
	for i in range(3):
		var drone: ScoutDrone = ScoutDroneScene.instantiate() as ScoutDrone
		drone.team = team
		drone.direction = facing.rotated((i - 1) * 0.5)
		drone.position = global_position + facing * DEPLOY_OFFSET
		get_parent().add_child(drone)
	cast_ability(ability)

func _can_act(ability: AbilityDefinition) -> bool:
	return (
		ability != null
		and state != State.DEAD
		and state != State.CASTING
		and not is_on_cooldown(ability)
	)

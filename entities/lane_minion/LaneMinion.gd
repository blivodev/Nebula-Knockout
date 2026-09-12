class_name LaneMinion
extends CharacterBody2D
## Lane minion: paths toward its waypoint via NavigationAgent2D, auto-
## attacks the nearest valid enemy in its aggro range (prioritizing other
## minions/structures over players unless a player attacks first), and
## pays out last-hit gold through MatchEconomy on death. Team A and Team B
## minions are the SAME scene with `team` toggled -- collision layers and
## aggro targeting are resolved at runtime so both sides are guaranteed
## symmetric.

signal died(last_hit_player_id: int)

const MOVE_SPEED: float = 120.0
const ATTACK_RANGE: float = 48.0
const ATTACK_DAMAGE: float = 18.0
const ATTACK_INTERVAL_SEC: float = 1.0
const MAX_HP: float = 250.0
const AGGRO_RANGE: float = 200.0

const TEAM_A_LAYER_BIT: int = 1
const TEAM_B_LAYER_BIT: int = 2
const STRUCTURES_LAYER_BIT: int = 6

@export var team: MatchState.Team = MatchState.Team.TEAM_A
@export var waypoints: Array[Vector2] = []

var current_hp: float = MAX_HP
var _waypoint_index: int = 0
var _attack_timer: float = 0.0
var _attack_target: Node2D = null
var _last_hit_player_id: int = -1 # last PLAYER (not minion) to damage us

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var visual: Polygon2D = $Visual
@onready var aggro_area: Area2D = $AggroArea

func _ready() -> void:
	add_to_group("minions")
	current_hp = MAX_HP
	visual.color = Color(0.35, 0.55, 0.9) if team == MatchState.Team.TEAM_A else Color(0.9, 0.4, 0.35)

	var own_bit: int = TEAM_A_LAYER_BIT if team == MatchState.Team.TEAM_A else TEAM_B_LAYER_BIT
	var enemy_bit: int = TEAM_B_LAYER_BIT if team == MatchState.Team.TEAM_A else TEAM_A_LAYER_BIT
	set_collision_layer_value(own_bit, true)
	set_collision_mask_value(TEAM_A_LAYER_BIT, true)
	set_collision_mask_value(TEAM_B_LAYER_BIT, true)
	set_collision_mask_value(STRUCTURES_LAYER_BIT, true)

	aggro_area.set_collision_mask_value(enemy_bit, true)
	aggro_area.set_collision_mask_value(STRUCTURES_LAYER_BIT, true)

	nav_agent.radius = 16.0
	if waypoints.size() > 0:
		nav_agent.target_position = waypoints[0]

	aggro_area.body_entered.connect(_on_aggro_body_entered)
	aggro_area.body_exited.connect(_on_aggro_body_exited)
	aggro_area.area_entered.connect(_on_aggro_area_entered)
	aggro_area.area_exited.connect(_on_aggro_area_exited)

func _physics_process(delta: float) -> void:
	if MatchState.phase != MatchState.Phase.IN_PROGRESS:
		return

	_attack_timer = max(0.0, _attack_timer - delta)

	if _attack_target != null and is_instance_valid(_attack_target):
		var dist: float = global_position.distance_to(_attack_target.global_position)
		if dist <= ATTACK_RANGE:
			velocity = Vector2.ZERO
			_try_attack()
			move_and_slide()
			return
	else:
		_attack_target = null

	_follow_path()

func _follow_path() -> void:
	if nav_agent.is_navigation_finished():
		_advance_waypoint()
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var next_point: Vector2 = nav_agent.get_next_path_position()
	velocity = global_position.direction_to(next_point) * MOVE_SPEED
	move_and_slide()

func _advance_waypoint() -> void:
	_waypoint_index += 1
	if _waypoint_index < waypoints.size():
		nav_agent.target_position = waypoints[_waypoint_index]

func _try_attack() -> void:
	if _attack_timer > 0.0 or _attack_target == null:
		return
	_attack_timer = ATTACK_INTERVAL_SEC
	if _attack_target.has_method("take_damage"):
		_attack_target.call("take_damage", ATTACK_DAMAGE, self)

func _on_aggro_body_entered(body: Node2D) -> void:
	if _attack_target != null:
		return
	if body is LaneMinion and body.team != team:
		_attack_target = body
	elif body is CharacterController and body.team != team:
		_attack_target = body

func _on_aggro_body_exited(body: Node2D) -> void:
	if body == _attack_target:
		_attack_target = null

func _on_aggro_area_entered(area: Area2D) -> void:
	if _attack_target != null:
		return
	var owner_node: Node = area.get_parent()
	if owner_node is MainBuilding and owner_node.team != team:
		_attack_target = owner_node
	elif owner_node is CharacterController and owner_node.team != team:
		_attack_target = owner_node

func _on_aggro_area_exited(area: Area2D) -> void:
	var owner_node: Node = area.get_parent()
	if owner_node == _attack_target:
		_attack_target = null

## Called by whatever hit us (an ability's hitbox, another minion, a
## tower). A CharacterController source force-locks aggro onto the
## attacking player and remembers them for last-hit gold.
func take_damage(amount: float, source: Node = null) -> void:
	current_hp = max(0.0, current_hp - amount)
	if source is CharacterController:
		var attacker := source as CharacterController
		if attacker.team != team:
			_last_hit_player_id = attacker.player_id
			_attack_target = attacker
	if current_hp <= 0.0:
		_die()

func _die() -> void:
	if _last_hit_player_id >= 0:
		MatchEconomy.on_minion_last_hit(_last_hit_player_id)
	died.emit(_last_hit_player_id)
	queue_free()

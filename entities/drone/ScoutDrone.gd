class_name ScoutDrone
extends Node2D
## Machinist's FPV recon drone. Flies forward, seeks the nearest enemy within
## seek_radius, and can be detonated by its owner (MachinistController) for an
## area burst. Expires on its own if left alive too long.

signal detonated(at_position: Vector2)

@export var team: MatchState.Team = MatchState.Team.TEAM_A
@export var speed: float = 260.0
@export var detonate_damage: float = 90.0
@export var detonate_radius: float = 120.0
@export var max_lifetime_sec: float = 20.0
@export var seek_radius: float = 300.0

var direction: Vector2 = Vector2.RIGHT
var _alive: bool = true

@onready var visual: Polygon2D = $Visual

func _ready() -> void:
	if visual != null:
		visual.color = Color(0.85, 0.65, 0.3)
	get_tree().create_timer(max_lifetime_sec).timeout.connect(_expire)

func _process(delta: float) -> void:
	if not _alive:
		return
	var target: Node2D = _nearest_enemy()
	if target != null:
		# Seek: steer toward the closest enemy while it stays in range.
		direction = global_position.direction_to(target.global_position).normalized()
	position += direction * speed * delta

func is_active() -> bool:
	return _alive

## Nearest living enemy hero/minion within seek_radius (drone recon ignores
## structures -- it hunts bodies, not buildings).
func _nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var min_dist: float = seek_radius
	for group in ["characters", "minions"]:
		for node in get_tree().get_nodes_in_group(group):
			if node == self or not is_instance_valid(node):
				continue
			var t: Variant = node.get("team")
			if t == null or int(t) == int(team):
				continue
			if node.has_method("is_alive") and not node.call("is_alive"):
				continue
			var hp: Variant = node.get("current_hp")
			if hp != null and float(hp) <= 0.0:
				continue
			var d: float = global_position.distance_to(node.global_position)
			if d <= min_dist:
				min_dist = d
				nearest = node
	return nearest

func detonate() -> void:
	if not _alive:
		return
	_alive = false
	AudioDirector.play_explosion()
	_apply_aoe_damage()
	detonated.emit(global_position)
	queue_free()

func _expire() -> void:
	if _alive:
		_alive = false
		queue_free()

func _apply_aoe_damage() -> void:
	for group in ["characters", "minions", "structures"]:
		for node in get_tree().get_nodes_in_group(group):
			if node == self:
				continue
			var node_team: Variant = node.get("team")
			if node_team != null and int(node_team) == int(team):
				continue # never damage allies
			var node_position: Variant = node.get("global_position")
			if node_position == null:
				continue
			if global_position.distance_to(node_position) > detonate_radius:
				continue
			if node.has_method("take_damage"):
				node.call("take_damage", detonate_damage, self)

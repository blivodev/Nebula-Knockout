class_name GroundZone
extends Node2D
## Persistent area-of-effect entity spawned by ZONE abilities (e.g. Pyra's
## Cinder Field). Damages every enemy inside its radius on a fixed tick
## interval, optionally applying an on-tick status, then despawns when its
## lifetime expires. Spawned and configured by CharacterController's
## _spawn_ground_zone() from the ability's data -- no bespoke hero code.

@export var team: MatchState.Team = MatchState.Team.TEAM_A
@export var radius: float = 120.0
@export var damage_per_tick: float = 10.0
@export var tick_interval: float = 0.5
@export var lifetime_sec: float = 3.0
@export var status_to_apply: StatusEffectDefinition
@export var source: Node = null

var _tick_timer: float = 0.0
var _life_timer: float = 0.0

func _ready() -> void:
	add_to_group("ground_zones")
	_build_visual()

func _process(delta: float) -> void:
	_life_timer += delta
	if _life_timer >= lifetime_sec:
		queue_free()
		return
	_tick_timer += delta
	if _tick_timer >= tick_interval:
		_tick_timer = 0.0
		_tick()

## One damage pulse: hits every enemy (hero/minion/structure) inside the
## radius, mirroring CharacterController._apply_aoe's target rules.
func _tick() -> void:
	for group in ["characters", "minions", "structures"]:
		for node in get_tree().get_nodes_in_group(group):
			if node == source:
				continue
			var node_team: Variant = node.get("team")
			if node_team == null or int(node_team) == int(team):
				continue
			var node_position: Variant = node.get("global_position")
			if node_position == null:
				continue
			if global_position.distance_to(node_position) > radius:
				continue
			if node.has_method("take_damage"):
				node.call("take_damage", damage_per_tick, source)
			if status_to_apply != null and node.has_method("apply_status"):
				node.call("apply_status", status_to_apply, source)

## Simple translucent disc so the hazard area is readable in-match.
func _build_visual() -> void:
	var points := PackedVector2Array()
	var segments: int = 24
	for i in range(segments):
		var angle: float = TAU * i / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = Color(1.0, 0.45, 0.15, 0.22)
	add_child(poly)

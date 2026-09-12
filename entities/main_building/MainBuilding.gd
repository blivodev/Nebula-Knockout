class_name MainBuilding
extends Node2D
## Team base structure. ONE shared scene for both teams -- visually
## distinct (recolored here, replaced with real MCP-generated art later)
## but hitbox/HP identical by construction, never by hand-tuning two
## separate scenes. Verified by tests/unit/test_map_symmetry.gd.

signal destroyed(team: MatchState.Team)
signal damaged(current_hp: float, max_hp: float)

const TEAM_A_COLOR: Color = Color(0.25, 0.55, 0.95)
const TEAM_B_COLOR: Color = Color(0.95, 0.35, 0.3)
const STRUCTURES_LAYER_BIT: int = 6

@export var team: MatchState.Team = MatchState.Team.TEAM_A
@export var max_hp: float = 3000.0

var current_hp: float
var _destroyed: bool = false

@onready var visual: Polygon2D = $Visual
@onready var hurtbox: Area2D = $Hurtbox

func _ready() -> void:
	add_to_group("structures")
	current_hp = max_hp
	visual.color = TEAM_A_COLOR if team == MatchState.Team.TEAM_A else TEAM_B_COLOR
	hurtbox.set_collision_layer_value(STRUCTURES_LAYER_BIT, true)

func take_damage(amount: float, _source: Node = null) -> void:
	if _destroyed:
		return
	current_hp = max(0.0, current_hp - amount)
	damaged.emit(current_hp, max_hp)
	if current_hp <= 0.0:
		_destroy()

func _destroy() -> void:
	_destroyed = true
	destroyed.emit(team)
	var winner: MatchState.Team = (
		MatchState.Team.TEAM_B if team == MatchState.Team.TEAM_A else MatchState.Team.TEAM_A
	)
	MatchState.end_match(winner)

func is_destroyed() -> bool:
	return _destroyed

## World-space bounding box, used by the map-symmetry test to verify both
## bases are exact mirrors of one another.
func get_world_bounds() -> Rect2:
	var shape_node: CollisionShape2D = hurtbox.get_node("CollisionShape2D")
	var rect_shape: RectangleShape2D = shape_node.shape
	var half: Vector2 = rect_shape.size * 0.5
	return Rect2(global_position - half, rect_shape.size)

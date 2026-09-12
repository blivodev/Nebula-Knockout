class_name Projectile
extends Area2D
## Generic ranged/magic projectile fired by SKILLSHOT abilities. Travels in a
## straight line, damages the first enemy it touches (or every enemy if
## piercing), optionally applies a status, and expires at max range.
##
## Configure the exported fields BEFORE add_child() -- _ready() bakes the
## collision layers and orientation from them.

@export var team: MatchState.Team = MatchState.Team.TEAM_A
@export var direction: Vector2 = Vector2.RIGHT
@export var speed: float = 700.0
@export var damage: float = 40.0
@export var max_range: float = 600.0
@export var pierce: bool = false
@export var color: Color = Color(1.0, 0.8, 0.3)
@export var status_to_apply: StatusEffectDefinition
@export var caster: Node = null

const LAYER_TEAM_A: int = 1
const LAYER_TEAM_B: int = 2
const LAYER_HITBOX: int = 4
const LAYER_STRUCTURES: int = 6

var _start: Vector2

@onready var visual: Polygon2D = $Visual

func _ready() -> void:
	_start = global_position
	if direction.length() > 0.01:
		rotation = direction.angle()
	if visual != null:
		visual.color = color
	var enemy_bit: int = LAYER_TEAM_B if team == MatchState.Team.TEAM_A else LAYER_TEAM_A
	set_collision_layer_value(LAYER_HITBOX, true)
	set_collision_mask_value(enemy_bit, true)
	set_collision_mask_value(LAYER_STRUCTURES, true)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	# A projectile must not outlive its caster: if the caster was freed, the
	# stored reference is dead and passing it to take_damage() would error.
	if caster != null and not is_instance_valid(caster):
		queue_free()
		return
	position += direction * speed * delta
	if global_position.distance_to(_start) >= max_range:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	_hit(body)

func _on_area_entered(area: Area2D) -> void:
	_hit(area.get_parent())

func _hit(target: Node) -> void:
	if target == null or target == caster:
		return
	var target_team: Variant = target.get("team")
	if target_team != null and int(target_team) == int(team):
		return # never damage allies
	if not target.has_method("take_damage"):
		return
	var source: Node = caster if (caster != null and is_instance_valid(caster)) else null
	target.call("take_damage", damage, source)
	if status_to_apply != null and target.has_method("apply_status"):
		target.call("apply_status", status_to_apply, source)
	if not pierce:
		queue_free()

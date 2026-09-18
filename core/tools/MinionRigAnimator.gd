class_name MinionRigAnimator
extends Node
## Drives small articulated creature limbs under a lane minion so the player
## sees actual legs/arms moving -- not just the body sprite squash/bob that
## MinionFlipbook already applies to the torso. The minion is a robotic
## creature, so this adds a simple quadruped-style leg rig beneath the
## creature sprite that scuttles when walking and stands/attacks when idle.
##
## It layers on top of the existing AnimatedSprite2D "Visual" body (never
## replaces it), using plain Node2D limb sprites whose rotations are driven
## per-state in _process() -- the same robust technique as CombatRigAnimator,
## which avoids Skeleton2D's singular-matrix hazards entirely.

const LEG_LENGTH := 18.0
const LEG_THICK := 6.0
const STRIDE_DEG := 22.0
const SCUTTLE_HZ := 6.0
const IDLE_HZ := 2.6

var _minion: LaneMinion
var _root: Node2D
var _leg_front_l: Node2D
var _leg_front_r: Node2D
var _leg_back_l: Node2D
var _leg_back_r: Node2D
var _time: float = 0.0
var _facing_sign: float = 1.0

## Attaches to a lane minion, building the leg rig just below the creature
## sprite so the feet stay on the ground. Call from LaneMinion._ready().
func setup(minion: LaneMinion) -> void:
	_minion = minion
	_root = Node2D.new()
	_root.name = "MinionRig"
	_root.z_index = -1
	minion.add_child(_root)

	var body_color: Color = Color(0.45, 0.9, 1.0) if minion.team == MatchState.Team.TEAM_A else Color(1.0, 0.45, 0.4)
	_leg_front_l = _make_leg("LegFrontL", body_color, Vector2(10.0, 2.0))
	_leg_front_r = _make_leg("LegFrontR", body_color, Vector2(10.0, 2.0))
	_leg_back_l = _make_leg("LegBackL", body_color.darkened(0.15), Vector2(-10.0, 2.0))
	_leg_back_r = _make_leg("LegBackR", body_color.darkened(0.15), Vector2(-10.0, 2.0))

## Builds one leg: a pivoting upper segment hanging from a hip that the
## creature body covers, plus a lower foot segment. The node origin sits at
## the hip so rotation swings the foot.
func _make_leg(leg_name: String, color: Color, hip_offset: Vector2) -> Node2D:
	var hip := Node2D.new()
	hip.name = leg_name
	hip.position = hip_offset
	_root.add_child(hip)

	var upper := Sprite2D.new()
	upper.name = "Upper"
	upper.centered = false
	upper.texture = _make_limb_texture(Vector2(LEG_THICK, LEG_LENGTH * 0.6), color)
	upper.position = Vector2(-LEG_THICK * 0.5, 0.0)
	hip.add_child(upper)

	var lower := Sprite2D.new()
	lower.name = "Lower"
	lower.centered = false
	lower.texture = _make_limb_texture(Vector2(LEG_THICK * 0.8, LEG_LENGTH * 0.6), color.darkened(0.2))
	lower.position = Vector2(-LEG_THICK * 0.4, LEG_LENGTH * 0.6)
	upper.add_child(lower)
	return hip

func _process(delta: float) -> void:
	if _minion == null or not is_instance_valid(_minion) or _root == null:
		return
	_time += delta
	# Legs sit at the creature base regardless of the body sprite's bob.
	_root.position = _minion.visual.position + Vector2(0.0, 18.0)

	if _minion.visual != null and _minion.visual.flip_h:
		_facing_sign = -1.0
	else:
		_facing_sign = 1.0

	var moving: bool = _minion._is_moving
	var attacking: bool = _minion.visual != null and _minion.visual.animation == "attack"

	if attacking:
		_leg_front_l.rotation = deg_to_rad(-14.0)
		_leg_front_r.rotation = deg_to_rad(14.0)
		_leg_back_l.rotation = deg_to_rad(12.0)
		_leg_back_r.rotation = deg_to_rad(-12.0)
		return

	if moving:
		var phase: float = _time * SCUTTLE_HZ * TAU
		var swing: float = sin(phase)
		_leg_front_l.rotation = deg_to_rad(swing * STRIDE_DEG)
		_leg_front_r.rotation = deg_to_rad(-swing * STRIDE_DEG)
		_leg_back_l.rotation = deg_to_rad(-swing * STRIDE_DEG)
		_leg_back_r.rotation = deg_to_rad(swing * STRIDE_DEG)
	else:
		var breathe: float = sin(_time * IDLE_HZ)
		var rest := breathe * 2.0
		_leg_front_l.rotation = deg_to_rad(4.0 + rest)
		_leg_front_r.rotation = deg_to_rad(-4.0 - rest)
		_leg_back_l.rotation = deg_to_rad(4.0 + rest)
		_leg_back_r.rotation = deg_to_rad(-4.0 - rest)

## Small solid-color rectangle limb with a darker outline (same approach as
## CombatRigAnimator) so the minion rig needs no external art.
func _make_limb_texture(size: Vector2, color: Color) -> ImageTexture:
	var w: int = maxi(2, int(round(size.x)))
	var h: int = maxi(2, int(round(size.y)))
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var outline: Color = color.darkened(0.55)
	for x in range(w):
		image.set_pixel(x, 0, outline)
		image.set_pixel(x, h - 1, outline)
	for y in range(h):
		image.set_pixel(0, y, outline)
		image.set_pixel(w - 1, y, outline)
	return ImageTexture.create_from_image(image)

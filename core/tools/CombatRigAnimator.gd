class_name CombatRigAnimator
extends Node
## Drives a real, limb-based animation rig for a hero in LIVE COMBAT,
## replacing the old whole-sprite procedural shake (HeroAnimator) so the
## player visibly sees arms and legs moving -- walking swings the limbs in
## a contralateral gait, attacking winds up and strikes with an arm, idling
## breathes, getting hit flinches, dying collapses.
##
## Unlike HeroRigAnimator (which builds a Skeleton2D/Bone2D chain), this rig
## uses a plain Node2D hierarchy of limb Sprite2Ds whose rotations are
## driven per-state in _process(). That avoids Skeleton2D's singular-matrix
## math on scaled, child-heavy chains (which spams `det == 0` affine_invert
## errors the moment many hero instances spawn) while still producing
## genuine swinging-limb animation.
##
## The rig is attached in CharacterController._setup_animator() and takes
## over the old "Visual" child's transform (the original art sprite is
## hidden, not removed, so anything else referencing "Visual" keeps working).

const WalkAnim := "walk"
const IdleAnim := "idle"
const AttackAnim := "attack"

# Limb geometry (world px, used when no matching old Visual scale exists).
const TORSO_SIZE := Vector2(34.0, 58.0)
const HEAD_SIZE := Vector2(24.0, 24.0)
const UPPER_ARM_SIZE := Vector2(12.0, 30.0)
const FOREARM_SIZE := Vector2(10.0, 26.0)
const UPPER_LEG_SIZE := Vector2(14.0, 32.0)
const LOWER_LEG_SIZE := Vector2(12.0, 30.0)

# Swing amplitude (degrees) and timing for the walk gait.
const ARM_SWING_DEG := 34.0
const LEG_SWING_DEG := 26.0
const WALK_HZ := 3.2
const IDLE_HZ := 2.4
const ATTACK_DURATION := 0.35

var _controller: CharacterController
var _root: Node2D
var _torso: Node2D
var _head: Node2D
var _arm_l_upper: Node2D
var _arm_l_lower: Node2D
var _arm_r_upper: Node2D
var _arm_r_lower: Node2D
var _leg_l_upper: Node2D
var _leg_l_lower: Node2D
var _leg_r_upper: Node2D
var _leg_r_lower: Node2D

var _facing_sign: float = 1.0
var _time: float = 0.0
var _hit_flash: float = 0.0
var _walk_phase: float = 0.0
var _attack_time: float = -1.0
var _base_scale: Vector2 = Vector2.ONE

## Attaches this animator to a controller, building the limb rig and hiding
## the original "Visual" child (kept in the tree so nothing else breaks).
func setup(controller: CharacterController) -> void:
	_controller = controller
	var tint: Color = Color.WHITE
	var old_visual := controller.get_node_or_null("Visual") as Node2D
	if old_visual != null:
		var tex: Texture2D = null
		if old_visual is Sprite2D and (old_visual as Sprite2D).texture != null:
			tex = (old_visual as Sprite2D).texture
			tint = HeroRigAnimator.average_tint(tex)
		old_visual.visible = false

	_root = Node2D.new()
	_root.name = "CombatRig"
	_root.z_index = 0
	_root.scale = Vector2.ONE
	_base_scale = _root.scale
	controller.add_child(_root)
	_build_limbs(tint)
	# Feet sit on the body origin: torso center is half the leg+torso height
	# above the feet, so we raise the torso by the leg stack.
	_torso.position = Vector2(0.0, -UPPER_LEG_SIZE.y - LOWER_LEG_SIZE.y)

	controller.state_changed.connect(_on_state_changed)

## Builds the limb hierarchy: torso (root of the upper body) with head and
## two articulated arms, plus two articulated legs hanging from the hips.
func _build_limbs(tint: Color) -> void:
	_torso = _limb("Torso", TORSO_SIZE, tint, Vector2.ZERO, Vector2.ZERO, true)
	_root.add_child(_torso)

	_head = _limb("Head", HEAD_SIZE, tint.lightened(0.15), Vector2(0.0, -TORSO_SIZE.y * 0.5), Vector2.ZERO, true)
	_torso.add_child(_head)

	var shoulder_y := -TORSO_SIZE.y * 0.32
	var hip_y := TORSO_SIZE.y * 0.5

	_arm_l_upper = _limb("ArmLU", UPPER_ARM_SIZE, tint.darkened(0.1), Vector2(-TORSO_SIZE.x * 0.42, shoulder_y), Vector2(0.0, UPPER_ARM_SIZE.y), false)
	_torso.add_child(_arm_l_upper)
	_arm_l_lower = _limb("ArmLL", FOREARM_SIZE, tint.darkened(0.25), Vector2.ZERO, Vector2.ZERO, true)
	_arm_l_upper.add_child(_arm_l_lower)

	_arm_r_upper = _limb("ArmRU", UPPER_ARM_SIZE, tint.darkened(0.1), Vector2(TORSO_SIZE.x * 0.42, shoulder_y), Vector2(0.0, UPPER_ARM_SIZE.y), false)
	_torso.add_child(_arm_r_upper)
	_arm_r_lower = _limb("ArmRL", FOREARM_SIZE, tint.darkened(0.25), Vector2.ZERO, Vector2.ZERO, true)
	_arm_r_upper.add_child(_arm_r_lower)

	_leg_l_upper = _limb("LegLU", UPPER_LEG_SIZE, tint.darkened(0.3), Vector2(-TORSO_SIZE.x * 0.22, hip_y), Vector2(0.0, UPPER_LEG_SIZE.y), false)
	_torso.add_child(_leg_l_upper)
	_leg_l_lower = _limb("LegLL", LOWER_LEG_SIZE, tint.darkened(0.4), Vector2.ZERO, Vector2.ZERO, true)
	_leg_l_upper.add_child(_leg_l_lower)

	_leg_r_upper = _limb("LegRU", UPPER_LEG_SIZE, tint.darkened(0.3), Vector2(TORSO_SIZE.x * 0.22, hip_y), Vector2(0.0, UPPER_LEG_SIZE.y), false)
	_torso.add_child(_leg_r_upper)
	_leg_r_lower = _limb("LegRL", LOWER_LEG_SIZE, tint.darkened(0.4), Vector2.ZERO, Vector2.ZERO, true)
	_leg_r_upper.add_child(_leg_r_lower)

## Creates one limb node. When `pivot_at_tip` is true, `pivot` places the
## node's origin at the joint top so rotation pivots around that joint and
## the limb hangs down; the Sprite2D child is offset so the limb body hangs
## below the origin. For non-pivoting nodes (torso/head/lower segments) the
## sprite is centered on the node.
func _limb(node_name: String, size: Vector2, color: Color, position: Vector2, pivot: Vector2, centered: bool) -> Node2D:
	var node := Node2D.new()
	node.name = node_name
	node.position = position
	var sprite := Sprite2D.new()
	sprite.name = "Visual"
	sprite.texture = _make_limb_texture(size, color)
	if centered:
		sprite.centered = true
	else:
		sprite.centered = false
		# Position so the limb hangs below its joint origin, centered on X.
		sprite.position = pivot + Vector2(-size.x * 0.5, 0.0)
	node.add_child(sprite)
	return node

func _process(delta: float) -> void:
	if _controller == null or not is_instance_valid(_controller) or _root == null:
		return
	_time += delta
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta * 4.0)
		_root.modulate = Color(1.8, 1.8, 1.8, 1.0).lerp(Color.WHITE, _hit_flash)

	if _controller.facing.x < -0.05:
		_facing_sign = -1.0
	elif _controller.facing.x > 0.05:
		_facing_sign = 1.0
	_root.scale.x = absf(_root.scale.x) * _facing_sign

	_reset_limbs(0.0)
	match _controller.state:
		CharacterController.State.WALK:
			_animate_walk(delta)
			_root.scale = Vector2(_base_scale.x * _facing_sign, _base_scale.y)
		CharacterController.State.CASTING:
			_animate_attack(delta)
			_root.scale = Vector2(_base_scale.x * _facing_sign, _base_scale.y)
		CharacterController.State.DASH:
			_root.rotation = 0.2 * _facing_sign
			_root.scale = Vector2(_base_scale.x * 1.22 * _facing_sign, _base_scale.y * 0.82)
		CharacterController.State.HIT:
			_root.rotation = -0.24 * _facing_sign
			_root.scale = Vector2(_base_scale.x * 0.92 * _facing_sign, _base_scale.y * 1.1)
		CharacterController.State.DEAD:
			_root.rotation = 0.5 * _facing_sign
			_root.scale = Vector2(_base_scale.x * 1.3 * _facing_sign, _base_scale.y * 0.3)
		_:
			_animate_idle(delta)
			_root.scale = Vector2(_base_scale.x * _facing_sign, _base_scale.y)

	if _controller.state != CharacterController.State.DASH and _controller.state != CharacterController.State.HIT:
		_root.rotation = lerp_angle(_root.rotation, 0.0, clampf(delta * 12.0, 0.0, 1.0))

func _reset_limbs(rot: float) -> void:
	_head.rotation = rot
	_arm_l_upper.rotation = rot
	_arm_l_lower.rotation = rot
	_arm_r_upper.rotation = rot
	_arm_r_lower.rotation = rot
	_leg_l_upper.rotation = rot
	_leg_l_lower.rotation = rot
	_leg_r_upper.rotation = rot
	_leg_r_lower.rotation = rot

func _animate_idle(delta: float) -> void:
	var breath: float = sin(_time * IDLE_HZ)
	_root.position.y = breath * 2.0
	_torso.rotation = breath * 0.04
	_arm_l_upper.rotation = deg_to_rad(4.0 + breath * 3.0)
	_arm_r_upper.rotation = deg_to_rad(-4.0 - breath * 3.0)
	_arm_l_lower.rotation = deg_to_rad(6.0 + breath * 2.0)
	_arm_r_lower.rotation = deg_to_rad(-6.0 - breath * 2.0)

func _animate_walk(delta: float) -> void:
	_walk_phase += delta * WALK_HZ * TAU
	_root.position.y = absf(sin(_walk_phase)) * -6.0
	_torso.rotation = sin(_walk_phase) * 0.05
	var swing: float = sin(_walk_phase)
	# Contralateral gait: left leg forward with right arm forward.
	_leg_l_upper.rotation = deg_to_rad(swing * -LEG_SWING_DEG)
	_leg_r_upper.rotation = deg_to_rad(-swing * -LEG_SWING_DEG)
	var knee_l: float = maxf(0.0, -swing)
	var knee_r: float = maxf(0.0, swing)
	_leg_l_lower.rotation = deg_to_rad(knee_l * 22.0)
	_leg_r_lower.rotation = deg_to_rad(knee_r * 22.0)
	_arm_l_upper.rotation = deg_to_rad(swing * ARM_SWING_DEG)
	_arm_r_upper.rotation = deg_to_rad(-swing * ARM_SWING_DEG)
	_arm_l_lower.rotation = deg_to_rad(8.0)
	_arm_r_lower.rotation = deg_to_rad(-8.0)

func _animate_attack(delta: float) -> void:
	if _attack_time < 0.0:
		_attack_time = 0.0
	_attack_time += delta
	var t: float = clampf(_attack_time / ATTACK_DURATION, 0.0, 1.0)
	# Windup then strike with the right arm; torso follows through.
	var windup: float = remap(t, 0.0, 0.35, 0.0, 1.0)
	var strike: float = remap(t, 0.35, 0.75, 0.0, 1.0)
	_arm_r_upper.rotation = lerp_angle(deg_to_rad(-12.0), deg_to_rad(-70.0), windup)
	_arm_r_upper.rotation = lerp_angle(_arm_r_upper.rotation, deg_to_rad(55.0), strike)
	_arm_r_lower.rotation = lerp_angle(deg_to_rad(12.0), deg_to_rad(-40.0), strike)
	_torso.rotation = lerp_angle(0.0, deg_to_rad(-12.0) * _facing_sign, windup)
	_arm_l_upper.rotation = lerp_angle(deg_to_rad(6.0), deg_to_rad(-14.0), windup)
	if t >= 1.0:
		_attack_time = -1.0

func _on_state_changed(new_state: int) -> void:
	if new_state == CharacterController.State.HIT:
		_hit_flash = 1.0

## A small solid-color rectangle with a darker outline -- the limb cutout,
## reusing the same generation approach as HeroRigAnimator so rigs stay
## self-contained (no external art dependency).
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

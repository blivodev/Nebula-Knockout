@tool
class_name HeroRigAnimator
extends RefCounted
## Builds a genuine skeletal (Bone2D chain) humanoid rig -- torso, head, two
## arms (upper_arm + forearm), two legs (upper_leg + lower_leg) -- with
## procedurally-generated placeholder cutout art per limb, plus a real
## AnimationPlayer driving "idle"/"walk"/"attack" cycles via keyframed bone
## rotations. This is TRUE skeletal animation: every limb is its own
## Bone2D, and AnimationPlayer keyframes rotate those bones directly, as
## opposed to HeroAnimator's whole-sprite procedural tweening used for live
## combat.
##
## Reserved for hero-select/menu showcase puppeteering, matching the
## locked decision in docs/ARCHITECTURE.md Section 3 ("Skeleton2D +
## Polygon2D cutout rigs are reserved for hero-select/menu showcase
## puppeteering only -- not live combat"). HeroShowcase wires this up per
## hero. HeroRigImporter (the other rig tool in this folder) stays focused
## on importing a real per-limb art JSON rig; this module needs no art
## assets at all, so it can run standalone before that art exists.
##
## Bone chain and local geometry (all in the parent bone's local space):
##   torso (root, origin = character center)
##     head            (above torso, no children)
##     upper_arm_l/r   -> forearm_l/r   (hangs down from the shoulder)
##     upper_leg_l/r   -> lower_leg_l/r (hangs down from the hip)
## Each limb's Sprite2D is offset so the bone's own origin sits at the
## joint end of the limb -- rotating the Bone2D pivots the sprite around
## that joint, and rotating a parent bone carries every descendant limb
## with it (ordinary Node2D transform inheritance), exactly like a rigid
## cutout skeleton.

const TORSO_SIZE := Vector2(34.0, 58.0)
const HEAD_SIZE := Vector2(26.0, 26.0)
const UPPER_ARM_SIZE := Vector2(12.0, 32.0)
const FOREARM_SIZE := Vector2(10.0, 28.0)
const UPPER_LEG_SIZE := Vector2(14.0, 34.0)
const LOWER_LEG_SIZE := Vector2(12.0, 32.0)

## Builds the full Skeleton2D rig for one hero tinted with `tint`, with an
## "AnimationPlayer" child already carrying "idle"/"walk"/"attack"
## animations (call get_node("AnimationPlayer").play(name) to start one).
static func build(hero_id: String, tint: Color) -> Skeleton2D:
	var skeleton := Skeleton2D.new()
	skeleton.name = "%s_Rig" % hero_id

	var torso := _make_bone("torso", TORSO_SIZE, tint, Vector2.ZERO, "center")
	skeleton.add_child(torso)

	var head := _make_bone("head", HEAD_SIZE, tint.lightened(0.15), Vector2(0.0, -TORSO_SIZE.y * 0.5), "up", HEAD_SIZE.y)
	torso.add_child(head)

	var shoulder_y: float = -TORSO_SIZE.y * 0.32
	var hip_y: float = TORSO_SIZE.y * 0.5

	var upper_arm_l := _make_bone("upper_arm_l", UPPER_ARM_SIZE, tint.darkened(0.1), Vector2(-TORSO_SIZE.x * 0.4, shoulder_y), "down")
	torso.add_child(upper_arm_l)
	var forearm_l := _make_bone("forearm_l", FOREARM_SIZE, tint.darkened(0.25), Vector2(0.0, UPPER_ARM_SIZE.y), "down", FOREARM_SIZE.y)
	upper_arm_l.add_child(forearm_l)

	var upper_arm_r := _make_bone("upper_arm_r", UPPER_ARM_SIZE, tint.darkened(0.1), Vector2(TORSO_SIZE.x * 0.4, shoulder_y), "down")
	torso.add_child(upper_arm_r)
	var forearm_r := _make_bone("forearm_r", FOREARM_SIZE, tint.darkened(0.25), Vector2(0.0, UPPER_ARM_SIZE.y), "down", FOREARM_SIZE.y)
	upper_arm_r.add_child(forearm_r)

	var upper_leg_l := _make_bone("upper_leg_l", UPPER_LEG_SIZE, tint.darkened(0.3), Vector2(-TORSO_SIZE.x * 0.22, hip_y), "down")
	torso.add_child(upper_leg_l)
	var lower_leg_l := _make_bone("lower_leg_l", LOWER_LEG_SIZE, tint.darkened(0.4), Vector2(0.0, UPPER_LEG_SIZE.y), "down", LOWER_LEG_SIZE.y)
	upper_leg_l.add_child(lower_leg_l)

	var upper_leg_r := _make_bone("upper_leg_r", UPPER_LEG_SIZE, tint.darkened(0.3), Vector2(TORSO_SIZE.x * 0.22, hip_y), "down")
	torso.add_child(upper_leg_r)
	var lower_leg_r := _make_bone("lower_leg_r", LOWER_LEG_SIZE, tint.darkened(0.4), Vector2(0.0, UPPER_LEG_SIZE.y), "down", LOWER_LEG_SIZE.y)
	upper_leg_r.add_child(lower_leg_r)

	_attach_animations(skeleton)
	return skeleton

## Total resting height from the top of the head to the bottom of the feet
## -- useful for callers that want to place the rig's feet on a ground line.
static func total_height() -> float:
	return HEAD_SIZE.y + TORSO_SIZE.y * 0.5 + UPPER_LEG_SIZE.y + LOWER_LEG_SIZE.y

## Distance from the torso bone (the rig's root/origin) straight down to
## the feet -- callers positioning the rig as a gameplay Visual (as opposed
## to HeroShowcase's own hand-tuned row offset) use this to sit the feet at
## the character body's own origin: `rig.position = Vector2(0, -feet_offset())`.
static func feet_offset() -> float:
	return UPPER_LEG_SIZE.y + LOWER_LEG_SIZE.y

## Samples a sparse grid of a texture's opaque pixels and averages them into
## one representative color -- used to tint a hero's placeholder combat rig
## from their actual MCP-generated portrait instead of a hand-authored color
## table, so every future hero (not just the ones with an entry in some
## lookup dict) gets a rig tint that actually matches their art.
static func average_tint(texture: Texture2D, sample_grid: int = 8) -> Color:
	if texture == null:
		return Color.WHITE
	var image: Image = texture.get_image()
	if image == null:
		return Color.WHITE
	var w: int = image.get_width()
	var h: int = image.get_height()
	if w <= 0 or h <= 0:
		return Color.WHITE
	var sum := Color(0.0, 0.0, 0.0, 0.0)
	var count: int = 0
	for gy in range(sample_grid):
		for gx in range(sample_grid):
			var px: int = clampi(int((float(gx) + 0.5) / float(sample_grid) * w), 0, w - 1)
			var py: int = clampi(int((float(gy) + 0.5) / float(sample_grid) * h), 0, h - 1)
			var pixel: Color = image.get_pixel(px, py)
			if pixel.a < 0.1: # skip transparent background pixels
				continue
			sum += pixel
			count += 1
	if count == 0:
		return Color.WHITE
	return Color(sum.r / count, sum.g / count, sum.b / count, 1.0)

## `leaf_length`: for a bone with NO Bone2D children (head, forearms, lower
## legs), Skeleton2D otherwise tries to auto-calculate the bone's editor-
## gizmo length/angle from a child that doesn't exist, which spams
## "Cannot calculate bone length or angle reliably" warnings and can hit a
## singular-matrix engine error on a moving rig. Passing the segment's
## real length here disables that autocalculation instead (Bone2D's own
## documented escape hatch for chain tips) -- purely bookkeeping, it has
## no effect on this rig's actual rendering, which is driven by the
## Sprite2D children directly.
static func _make_bone(bone_name: String, size: Vector2, color: Color, local_position: Vector2, hang: String, leaf_length: float = -1.0) -> Bone2D:
	var bone := Bone2D.new()
	bone.name = bone_name
	bone.position = local_position
	if leaf_length >= 0.0:
		bone.set_autocalculate_length_and_angle(false)
		bone.set_length(leaf_length)
		bone.set_bone_angle(0.0)

	var sprite := Sprite2D.new()
	sprite.name = "Visual"
	sprite.centered = false
	sprite.z_as_relative = true
	sprite.texture = _make_limb_texture(size, color)
	match hang:
		"down": # bone origin is the joint at the TOP of the limb (shoulder/hip/elbow/knee)
			sprite.offset = Vector2(-size.x * 0.5, 0.0)
		"up": # bone origin is the joint at the BOTTOM of the limb (neck, for the head)
			sprite.offset = Vector2(-size.x * 0.5, -size.y)
		_: # centered -- only the torso root, which has no single parent joint
			sprite.offset = -size * 0.5
	bone.add_child(sprite)
	return bone

## A small solid-color rectangle with a darker 1px outline -- a stand-in
## cutout limb texture generated entirely in-engine, so this rig needs no
## external art files to demonstrate real bone-driven motion.
static func _make_limb_texture(size: Vector2, color: Color) -> ImageTexture:
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

static func _attach_animations(skeleton: Skeleton2D) -> AnimationPlayer:
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	skeleton.add_child(player)
	var lib := AnimationLibrary.new()
	lib.add_animation(&"idle", _build_idle_animation())
	lib.add_animation(&"walk", _build_walk_animation())
	lib.add_animation(&"attack", _build_attack_animation())
	player.add_animation_library("", lib)
	return player

## keys: Array of [time_sec, degrees] pairs, in order.
static func _add_rotation_track(anim: Animation, bone_path: String, keys: Array) -> void:
	var idx: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(idx, NodePath("%s:rotation" % bone_path))
	anim.track_set_interpolation_type(idx, Animation.INTERPOLATION_LINEAR)
	for key in keys:
		anim.track_insert_key(idx, key[0], deg_to_rad(key[1]))

## Gentle breathing sway -- torso rocks, arms drift, head tilts.
static func _build_idle_animation() -> Animation:
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_LINEAR
	var length: float = 1.6
	anim.length = length
	_add_rotation_track(anim, "torso", [[0.0, -2.0], [length * 0.5, 2.0], [length, -2.0]])
	_add_rotation_track(anim, "torso/head", [[0.0, -2.0], [length * 0.5, 2.0], [length, -2.0]])
	_add_rotation_track(anim, "torso/upper_arm_l", [[0.0, 6.0], [length * 0.5, 10.0], [length, 6.0]])
	_add_rotation_track(anim, "torso/upper_arm_r", [[0.0, -6.0], [length * 0.5, -10.0], [length, -6.0]])
	_add_rotation_track(anim, "torso/upper_arm_l/forearm_l", [[0.0, 4.0], [length * 0.5, 8.0], [length, 4.0]])
	_add_rotation_track(anim, "torso/upper_arm_r/forearm_r", [[0.0, -4.0], [length * 0.5, -8.0], [length, -4.0]])
	return anim

## Full walk cycle -- opposing arm/leg swing (left leg forward with right
## arm forward, classic contralateral gait), knee bend on the leading leg,
## and a subtle torso counter-rotation.
static func _build_walk_animation() -> Animation:
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_LINEAR
	var length: float = 0.9
	anim.length = length
	var half: float = length * 0.5
	var quarter: float = length * 0.25
	var three_quarter: float = length * 0.75

	_add_rotation_track(anim, "torso", [[0.0, -3.0], [half, 3.0], [length, -3.0]])

	_add_rotation_track(anim, "torso/upper_arm_l", [[0.0, 28.0], [half, -28.0], [length, 28.0]])
	_add_rotation_track(anim, "torso/upper_arm_l/forearm_l", [[0.0, 12.0], [half, 30.0], [length, 12.0]])
	_add_rotation_track(anim, "torso/upper_arm_r", [[0.0, -28.0], [half, 28.0], [length, -28.0]])
	_add_rotation_track(anim, "torso/upper_arm_r/forearm_r", [[0.0, 30.0], [half, 12.0], [length, 30.0]])

	_add_rotation_track(anim, "torso/upper_leg_l", [[0.0, -25.0], [half, 25.0], [length, -25.0]])
	_add_rotation_track(anim, "torso/upper_leg_l/lower_leg_l", [[0.0, 18.0], [quarter, 32.0], [half, 0.0], [three_quarter, 5.0], [length, 18.0]])
	_add_rotation_track(anim, "torso/upper_leg_r", [[0.0, 25.0], [half, -25.0], [length, 25.0]])
	_add_rotation_track(anim, "torso/upper_leg_r/lower_leg_r", [[0.0, 0.0], [quarter, 5.0], [half, 18.0], [three_quarter, 32.0], [length, 0.0]])
	return anim

## Quick one-shot windup + strike with the right arm (a real bone-driven
## attack pose, distinct from HeroAnimator's whole-sprite lunge used
## in-combat), torso following through on the swing.
static func _build_attack_animation() -> Animation:
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_NONE
	var length: float = 0.45
	anim.length = length
	_add_rotation_track(anim, "torso", [[0.0, 0.0], [0.28, -10.0], [length, 0.0]])
	_add_rotation_track(anim, "torso/upper_arm_r", [[0.0, -10.0], [0.15, -75.0], [0.28, 65.0], [length, -10.0]])
	_add_rotation_track(anim, "torso/upper_arm_r/forearm_r", [[0.0, 10.0], [0.15, 25.0], [0.28, -45.0], [length, 10.0]])
	_add_rotation_track(anim, "torso/upper_arm_l", [[0.0, 8.0], [0.28, -15.0], [length, 8.0]])
	return anim

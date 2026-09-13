class_name MinionFlipbook
extends RefCounted
## Bakes a real SpriteFrames flipbook (idle/walk/attack) from the lane
## minion's single-pose cutout art, replacing the old continuous
## per-_process procedural squash/offset transform with discrete
## pre-baked frames -- genuine sprite-sheet-style AnimatedSprite2D
## animation, matching docs/ARCHITECTURE.md's "AnimatedSprite2D/
## SpriteFrames flipbooks drive actual combat" decision. Team tinting and
## the on-hit flash stay as AnimatedSprite2D.modulate (a color effect,
## orthogonal to which pose-frame is showing), exactly like before.
##
## Frames are generated once from the source texture (a non-uniform
## Image.resize() per frame fakes squash/stretch) and cached statically by
## the caller -- baking is a handful of resize() calls, cheap, but doing
## it once for every minion that ever spawns rather than once per
## instance keeps wave-spawning free of redundant work.

## Per-frame non-uniform scale applied to the base texture to fake a
## breathing squash while idle.
const IDLE_SQUASH: Array[Vector2] = [
	Vector2(1.0, 1.0), Vector2(0.985, 1.02), Vector2(1.0, 1.0), Vector2(1.015, 0.98),
]
## Per-frame squash/stretch for the step cycle: compress on plant, stretch
## on push-off, mirrored across the two "legs" of the cycle.
const WALK_SQUASH: Array[Vector2] = [
	Vector2(1.05, 0.92), Vector2(0.98, 1.04), Vector2(0.94, 1.1),
	Vector2(1.05, 0.92), Vector2(0.98, 1.04), Vector2(1.0, 1.0),
]
## Per-frame vertical bob (world px, negative = up), indexed by the walk
## frame -- a discrete flipbook hop keyed to the actual frame being shown,
## instead of a continuous sine wave independent of the sprite.
const WALK_BOB: Array[float] = [-2.0, -8.0, -2.0, -2.0, -8.0, -2.0]
## Per-frame stretch for the attack lunge/pop, non-looping.
const ATTACK_STRETCH: Array[Vector2] = [
	Vector2(1.0, 1.0), Vector2(1.18, 0.9), Vector2(1.3, 0.85), Vector2(1.05, 0.97),
]

const IDLE_FPS: float = 4.0
const WALK_FPS: float = 10.0
const ATTACK_FPS: float = 12.0

## Builds a SpriteFrames with "idle"/"walk"/"attack" animations baked from
## `base_texture`. Callers should cache the result (see LaneMinion's
## `_shared_frames` static) rather than rebuilding per instance.
static func build(base_texture: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	var base_image: Image = base_texture.get_image()

	_add_animation(frames, "idle", base_image, IDLE_SQUASH, IDLE_FPS, true)
	_add_animation(frames, "walk", base_image, WALK_SQUASH, WALK_FPS, true)
	_add_animation(frames, "attack", base_image, ATTACK_STRETCH, ATTACK_FPS, false)
	return frames

static func _add_animation(frames: SpriteFrames, anim_name: String, base_image: Image, squash: Array[Vector2], fps: float, loop: bool) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, loop)
	for factor in squash:
		frames.add_frame(anim_name, _squashed_frame(base_image, factor.x, factor.y))

## Non-uniformly resizes a copy of the base image -- a cheap way to bake a
## distinct squash/stretch pose into its own real frame texture (as
## opposed to scaling the live Sprite2D node every frame).
static func _squashed_frame(base_image: Image, scale_x: float, scale_y: float) -> ImageTexture:
	var w: int = base_image.get_width()
	var h: int = base_image.get_height()
	var new_w: int = maxi(1, int(round(w * scale_x)))
	var new_h: int = maxi(1, int(round(h * scale_y)))
	var resized: Image = base_image.duplicate()
	resized.resize(new_w, new_h, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(resized)

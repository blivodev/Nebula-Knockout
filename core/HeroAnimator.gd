class_name HeroAnimator
extends Node
## Procedural "juice" animation for a hero's Visual node, driven by the
## CharacterController's state and facing direction. Gives every hero
## lively idle breathing, bouncy walking swagger with stepping tilt,
## directional attack lunges, impact flinches, and speed streaks.

const WALK_BOB_HZ: float = 11.0
const IDLE_BOB_HZ: float = 2.8

var _controller: CharacterController
var _visual: Node2D
var _base_scale: Vector2 = Vector2.ONE
var _base_position: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _flash: float = 0.0
var _facing_sign: float = 1.0

func setup(controller: CharacterController, visual: Node2D) -> void:
	_controller = controller
	_visual = visual
	_base_scale = visual.scale
	_base_position = visual.position
	_facing_sign = 1.0 if _base_scale.x >= 0.0 else -1.0
	if controller != null:
		controller.state_changed.connect(_on_state_changed)

func _process(delta: float) -> void:
	if _visual == null or _controller == null or not is_instance_valid(_controller):
		return
	_time += delta

	# Track horizontal facing so the sprite flips when moving or aiming left
	if _controller.facing.x < -0.05:
		_facing_sign = -1.0
	elif _controller.facing.x > 0.05:
		_facing_sign = 1.0

	var offset := Vector2.ZERO
	var target_scale := _base_scale
	target_scale.x = abs(_base_scale.x) * _facing_sign
	var target_rotation: float = 0.0

	match _controller.state:
		CharacterController.State.WALK:
			# Bouncy brawler walk cycle with stepping tilt
			var step_phase: float = _time * WALK_BOB_HZ
			offset.y = -abs(sin(step_phase)) * 10.0
			target_rotation = sin(step_phase) * 0.12 * _facing_sign
			var squash: float = sin(step_phase * 2.0) * 0.06
			target_scale.x = abs(_base_scale.x) * (1.0 - squash) * _facing_sign
			target_scale.y = _base_scale.y * (1.0 + squash)

		CharacterController.State.CASTING:
			# Attack windup & explosive thrust along facing direction
			offset += _controller.facing.normalized() * 16.0
			target_rotation = 0.14 * _facing_sign
			target_scale.x = abs(_base_scale.x) * 1.22 * _facing_sign
			target_scale.y = _base_scale.y * 0.88

		CharacterController.State.DASH:
			# Speed streak elongation
			offset += _controller.facing.normalized() * 12.0
			target_rotation = 0.18 * _facing_sign
			target_scale.x = abs(_base_scale.x) * 1.40 * _facing_sign
			target_scale.y = _base_scale.y * 0.74

		CharacterController.State.HIT:
			# Rapid impact shake & backward flinch
			offset.x = sin(_time * 48.0) * 8.0
			target_rotation = -0.22 * _facing_sign
			target_scale.x = abs(_base_scale.x) * 0.88 * _facing_sign
			target_scale.y = _base_scale.y * 1.15

		CharacterController.State.DEAD:
			# Flatten onto the ground
			offset.y = 22.0
			target_rotation = 0.45 * _facing_sign
			target_scale.x = abs(_base_scale.x) * 1.35 * _facing_sign
			target_scale.y = _base_scale.y * 0.28

		_:
			# Lively idle breathing & gentle sway
			var breath: float = sin(_time * IDLE_BOB_HZ)
			offset.y = breath * 5.0
			target_rotation = sin(_time * (IDLE_BOB_HZ * 0.5)) * 0.035
			target_scale.x = abs(_base_scale.x) * (1.0 + breath * 0.035) * _facing_sign
			target_scale.y = _base_scale.y * (1.0 - breath * 0.035)

	# Smoothly interpolate position, scale, and rotation
	_visual.position = _visual.position.lerp(_base_position + offset, clampf(delta * 22.0, 0.0, 1.0))
	_visual.scale = _visual.scale.lerp(target_scale, clampf(delta * 20.0, 0.0, 1.0))
	_visual.rotation = lerp_angle(_visual.rotation, target_rotation, clampf(delta * 16.0, 0.0, 1.0))

	# Damage flash effect
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 4.0)
		_visual.modulate = Color(1.0, 1.0 - _flash * 0.75, 1.0 - _flash * 0.75)
	elif _visual.modulate != Color.WHITE and _controller.state != CharacterController.State.DEAD:
		_visual.modulate = Color.WHITE

func _on_state_changed(new_state: int) -> void:
	if new_state == CharacterController.State.HIT:
		_flash = 1.0

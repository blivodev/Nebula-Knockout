class_name HeroAnimator
extends Node
## Procedural "juice" animation for a hero's Visual node, driven by the
## CharacterController's state. This is the stopgap until baked SpriteFrames
## flipbooks exist (docs/ARCHITECTURE.md Section 3): it gives every hero
## visible idle bob / walk sway / cast pop / hit flash / dash stretch / death
## squash with no art frames required, and it keeps working unchanged if the
## Visual later becomes an AnimatedSprite2D.

const WALK_BOB_HZ: float = 7.0
const IDLE_BOB_HZ: float = 1.5

var _controller: CharacterController
var _visual: Node2D
var _base_scale: Vector2 = Vector2.ONE
var _base_position: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _flash: float = 0.0

func setup(controller: CharacterController, visual: Node2D) -> void:
	_controller = controller
	_visual = visual
	_base_scale = visual.scale
	_base_position = visual.position
	if controller != null:
		controller.state_changed.connect(_on_state_changed)

func _process(delta: float) -> void:
	if _visual == null or _controller == null or not is_instance_valid(_controller):
		return
	_time += delta

	var offset := Vector2.ZERO
	var target_scale := _base_scale
	match _controller.state:
		CharacterController.State.WALK:
			var bob: float = sin(_time * WALK_BOB_HZ)
			offset.y = bob * 3.0
			target_scale = _base_scale * Vector2(1.0 + bob * 0.03, 1.0 - bob * 0.03)
		CharacterController.State.CASTING:
			target_scale = _base_scale * Vector2(1.14, 0.9)
		CharacterController.State.DASH:
			target_scale = _base_scale * Vector2(1.28, 0.78)
		CharacterController.State.HIT:
			offset.x = sin(_time * 45.0) * 3.0
			target_scale = _base_scale * Vector2(0.92, 1.08)
		CharacterController.State.DEAD:
			target_scale = _base_scale * Vector2(1.1, 0.55)
		_:
			offset.y = sin(_time * IDLE_BOB_HZ) * 2.0

	_visual.position = _base_position + offset
	_visual.scale = _visual.scale.lerp(target_scale, clampf(delta * 18.0, 0.0, 1.0))

	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 4.0)
		_visual.modulate = Color(1.0, 1.0 - _flash * 0.65, 1.0 - _flash * 0.65)
	elif _visual.modulate != Color.WHITE:
		_visual.modulate = Color.WHITE

func _on_state_changed(new_state: int) -> void:
	if new_state == CharacterController.State.HIT:
		_flash = 1.0

class_name LaneMinion
extends CharacterBody2D
## Lane minion: paths toward its waypoint via NavigationAgent2D, auto-
## attacks the nearest valid enemy in its aggro range (prioritizing other
## minions/structures over players unless a player attacks first), and
## pays out last-hit gold through MatchEconomy on death. Team A and Team B
## minions are the SAME scene with `team` toggled -- collision layers and
## aggro targeting are resolved at runtime so both sides are guaranteed
## symmetric.

signal died(last_hit_player_id: int)

const BaseVisualTexture: Texture2D = preload("res://art/minions/lane_minion.png")

const MOVE_SPEED: float = 120.0
const ATTACK_RANGE: float = 48.0
const ATTACK_DAMAGE: float = 18.0
const ATTACK_INTERVAL_SEC: float = 1.0
const MAX_HP: float = 250.0
const AGGRO_RANGE: float = 200.0

const TEAM_A_LAYER_BIT: int = 1
const TEAM_B_LAYER_BIT: int = 2
const STRUCTURES_LAYER_BIT: int = 6
const WALL_BLOCKS_A_BIT: int = 7 # occupied by enemy (TEAM_B) BulwarkWalls
const WALL_BLOCKS_B_BIT: int = 8 # occupied by enemy (TEAM_A) BulwarkWalls

@export var team: MatchState.Team = MatchState.Team.TEAM_A
@export var waypoints: Array[Vector2] = []

var current_hp: float = MAX_HP
var _waypoint_index: int = 0
var _attack_timer: float = 0.0
var _attack_target: Node2D = null
var _last_hit_player_id: int = -1 # last PLAYER (not minion) to damage us
var _knockback_timer: float = 0.0

# -- Visual/animation-only state (never read by AI/collision logic) --------
var _visual_base_position: Vector2 = Vector2.ZERO
var _team_tint: Color = Color.WHITE
var _facing_sign: float = 1.0
var _is_moving: bool = false
var _hit_flash: float = 0.0
var _anim_time: float = 0.0

## Baked once (see MinionFlipbook) and shared by every minion instance --
## rebuilding a SpriteFrames per spawn would redo the same Image.resize()
## work for every wave.
static var _shared_frames: SpriteFrames = null

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var visual: AnimatedSprite2D = $Visual
@onready var aggro_area: Area2D = $AggroArea

func _ready() -> void:
	add_to_group("minions")
	current_hp = MAX_HP
	if visual != null:
		if LaneMinion._shared_frames == null:
			LaneMinion._shared_frames = MinionFlipbook.build(BaseVisualTexture)
		visual.sprite_frames = LaneMinion._shared_frames
		_visual_base_position = visual.position
		# Team-colored creature sprite (shared art, tinted per side so both
		# teams read at a glance -- same shared-scene approach the old
		# procedural polygon used, now applied via AnimatedSprite2D.modulate).
		_team_tint = Color(0.55, 0.9, 1.55) if team == MatchState.Team.TEAM_A else Color(1.55, 0.65, 0.6)
		visual.modulate = _team_tint
		visual.play("idle")

	# Articulated creature legs under the flipbook body (scuttle on walk,
	# stand on idle, brace on attack), layered on top of the torso animation.
	var rig := MinionRigAnimator.new()
	rig.name = "MinionRigAnimator"
	add_child(rig)
	rig.setup(self)

	var own_bit: int = TEAM_A_LAYER_BIT if team == MatchState.Team.TEAM_A else TEAM_B_LAYER_BIT
	var enemy_bit: int = TEAM_B_LAYER_BIT if team == MatchState.Team.TEAM_A else TEAM_A_LAYER_BIT
	set_collision_layer_value(own_bit, true)
	set_collision_mask_value(TEAM_A_LAYER_BIT, true)
	set_collision_mask_value(TEAM_B_LAYER_BIT, true)
	set_collision_mask_value(STRUCTURES_LAYER_BIT, true)
	# Blocked only by walls owned by the ENEMY team (allied walls are passable).
	if team == MatchState.Team.TEAM_A:
		set_collision_mask_value(WALL_BLOCKS_A_BIT, true)
	else:
		set_collision_mask_value(WALL_BLOCKS_B_BIT, true)

	aggro_area.set_collision_mask_value(enemy_bit, true)
	aggro_area.set_collision_mask_value(STRUCTURES_LAYER_BIT, true)

	nav_agent.radius = 16.0
	if waypoints.size() > 0:
		nav_agent.target_position = waypoints[0]

	aggro_area.body_entered.connect(_on_aggro_body_entered)
	aggro_area.body_exited.connect(_on_aggro_body_exited)
	aggro_area.area_entered.connect(_on_aggro_area_entered)
	aggro_area.area_exited.connect(_on_aggro_area_exited)

## Purely cosmetic sprite animation (flipbook walk/idle/attack, facing
## flip, hit flash). Runs every frame independent of the physics/AI step
## above so it can never affect collision, movement, or aggro/attack
## timing.
func _process(delta: float) -> void:
	if visual == null:
		return
	_anim_time += delta
	_hit_flash = maxf(0.0, _hit_flash - delta * 4.0)

	visual.flip_h = _facing_sign < 0.0

	# Discrete flipbook hop, keyed to the actual walk frame being shown
	# (rather than a continuous sine wave independent of the sprite).
	var bob: float = 0.0
	if visual.animation == "walk":
		var idx: int = clampi(visual.frame, 0, MinionFlipbook.WALK_BOB.size() - 1)
		bob = MinionFlipbook.WALK_BOB[idx]
	visual.position = _visual_base_position + Vector2(0.0, bob)

	# Flash toward white on a hit, settle back to the team tint.
	visual.modulate = _team_tint.lerp(Color(1.9, 1.9, 1.9, 1.0), _hit_flash)

	_update_animation()

## Picks which baked animation should be showing. An in-flight "attack"
## always plays to completion before switching back to walk/idle.
func _update_animation() -> void:
	if visual.animation == "attack" and visual.is_playing():
		return
	var desired: String = "walk" if _is_moving else "idle"
	if visual.animation != desired:
		visual.play(desired)

func _physics_process(delta: float) -> void:
	if MatchState.phase != MatchState.Phase.IN_PROGRESS:
		return

	if _knockback_timer > 0.0:
		_knockback_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
		move_and_slide()
		_is_moving = false
		return

	_attack_timer = max(0.0, _attack_timer - delta)

	if _attack_target != null and is_instance_valid(_attack_target):
		var dist: float = global_position.distance_to(_attack_target.global_position)
		if dist <= ATTACK_RANGE:
			velocity = Vector2.ZERO
			_is_moving = false
			_try_attack()
			move_and_slide()
			return
	else:
		_attack_target = null

	_follow_path()

func _follow_path() -> void:
	if nav_agent.is_navigation_finished():
		_advance_waypoint()
		velocity = Vector2.ZERO
		_is_moving = false
		move_and_slide()
		return
	var next_point: Vector2 = nav_agent.get_next_path_position()
	velocity = global_position.direction_to(next_point) * MOVE_SPEED
	move_and_slide()
	_is_moving = true
	if velocity.x < -1.0:
		_facing_sign = -1.0
	elif velocity.x > 1.0:
		_facing_sign = 1.0

func _advance_waypoint() -> void:
	_waypoint_index += 1
	if _waypoint_index < waypoints.size():
		nav_agent.target_position = waypoints[_waypoint_index]

func _try_attack() -> void:
	if _attack_timer > 0.0 or _attack_target == null:
		return
	_attack_timer = ATTACK_INTERVAL_SEC
	if visual != null:
		visual.play("attack") # baked lunge/pop flipbook, see MinionFlipbook
	if _attack_target != null and is_instance_valid(_attack_target):
		_facing_sign = 1.0 if _attack_target.global_position.x >= global_position.x else -1.0
	if _attack_target.has_method("take_damage"):
		_attack_target.call("take_damage", ATTACK_DAMAGE, self)

func _on_aggro_body_entered(body: Node2D) -> void:
	if _attack_target != null:
		return
	if body is LaneMinion and body.team != team:
		_attack_target = body
	elif body is CharacterController and body.team != team:
		_attack_target = body

func _on_aggro_body_exited(body: Node2D) -> void:
	if body == _attack_target:
		_attack_target = null

func _on_aggro_area_entered(area: Area2D) -> void:
	if _attack_target != null:
		return
	var owner_node: Node = area.get_parent()
	if owner_node is MainBuilding and owner_node.team != team:
		_attack_target = owner_node
	elif owner_node is CharacterController and owner_node.team != team:
		_attack_target = owner_node

func _on_aggro_area_exited(area: Area2D) -> void:
	var owner_node: Node = area.get_parent()
	if owner_node == _attack_target:
		_attack_target = null

## Called by whatever hit us (an ability's hitbox, another minion, a
## tower). A CharacterController source force-locks aggro onto the
## attacking player and remembers them for last-hit gold.
func take_damage(amount: float, source: Node = null, knockback: Vector2 = Vector2.ZERO) -> void:
	current_hp = max(0.0, current_hp - amount)
	_hit_flash = 1.0 # visual-only flash, decays in _process
	if knockback.length_squared() > 0.0:
		velocity = knockback
		_knockback_timer = 0.2
	if source is CharacterController:
		var attacker := source as CharacterController
		if attacker.team != team:
			_last_hit_player_id = attacker.player_id
			_attack_target = attacker
	if current_hp <= 0.0:
		_die()

func _die() -> void:
	_spawn_death_poof()
	if _last_hit_player_id >= 0:
		MatchEconomy.on_minion_last_hit(_last_hit_player_id)
	died.emit(_last_hit_player_id)
	queue_free()

## Cosmetic-only: leaves a quick fading/scaling ghost of the creature sprite
## behind on death. Spawned as an independent node so it never delays this
## minion's own removal, last-hit payout, or the `died` signal timing.
func _spawn_death_poof() -> void:
	if visual == null or not is_instance_valid(visual):
		return
	var parent: Node = get_parent()
	if parent == null:
		return
	var frame_texture: Texture2D = null
	if visual.sprite_frames != null and visual.sprite_frames.has_animation(visual.animation):
		frame_texture = visual.sprite_frames.get_frame_texture(visual.animation, visual.frame)
	var ghost := Sprite2D.new()
	ghost.texture = frame_texture
	ghost.flip_h = visual.flip_h
	ghost.modulate = visual.modulate
	ghost.scale = visual.scale
	ghost.global_position = visual.global_position
	ghost.z_index = visual.z_index
	parent.add_child(ghost)
	var tween: Tween = ghost.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.3)
	tween.tween_property(ghost, "scale", ghost.scale * 0.4, 0.3)
	tween.tween_property(ghost, "position:y", ghost.position.y - 14.0, 0.3)
	tween.chain().tween_callback(ghost.queue_free)

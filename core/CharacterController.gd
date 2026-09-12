class_name CharacterController
extends CharacterBody2D
## Base state machine for every playable hero (see docs/ARCHITECTURE.md,
## Combat Framework). Concrete heroes assign a HeroDefinition + their 3
## skills/ultimate; this class owns the universal states (idle, walk,
## dash, jump, hit, block, cast, dead), the frame-data driven hit/hurtbox
## timing every ability plugs into, and local player input. Expects two
## optional child Area2D nodes named "Hurtbox" and "Hitbox".

signal state_changed(new_state: State)
signal hit_landed(target: Node, damage: float)
signal died

enum State { IDLE, WALK, DASH, JUMP, HIT, BLOCK, CASTING, DEAD }

# Physics layer bit indices, matching project.godot [layer_names].
const LAYER_TEAM_A: int = 1
const LAYER_TEAM_B: int = 2
const LAYER_HITBOX: int = 4
const LAYER_STRUCTURES: int = 6

const ProjectileScene: PackedScene = preload("res://entities/projectile/Projectile.tscn")

@export var hero_definition: HeroDefinition
@export var team: MatchState.Team = MatchState.Team.TEAM_A
@export var player_id: int = -1
## When true this hero reads local keyboard input (WASD to move, Q/E/R/F for
## skills). Direct key polling is deliberate for the prototype; converting to
## named InputMap actions (for remapping/controller support) is a follow-up.
@export var is_player_controlled: bool = false
## Adds a procedural HeroAnimator to the "Visual" child (idle bob, walk sway,
## cast pop, hit flash, dash stretch). Set false in tests that assert on the
## Visual transform directly.
@export var visual_animation_enabled: bool = true

var state: State = State.IDLE
## Last non-zero movement direction; used by directional abilities (dashes)
## so a cast goes where the player was last heading.
var facing: Vector2 = Vector2.RIGHT
var current_hp: float = 0.0
var max_hp: float = 0.0
var move_speed: float = 0.0
var dash_speed: float = 0.0

var _hitstun_timer: float = 0.0
var _block_active: bool = false
var _active_ability: AbilityDefinition = null
var _ability_frame_timer: float = 0.0
var _ability_phase: String = "" # "startup" | "active" | "recovery"
var _cooldowns: Dictionary = {} # ability_id: StringName -> seconds remaining
var _statuses: Array[ActiveStatus] = []

@onready var hurtbox: Area2D = get_node_or_null("Hurtbox")
@onready var hitbox: Area2D = get_node_or_null("Hitbox")

func _ready() -> void:
	add_to_group("characters")
	if hero_definition != null:
		max_hp = hero_definition.base_max_hp
		move_speed = hero_definition.base_move_speed
		dash_speed = hero_definition.base_dash_speed
	current_hp = max_hp
	_configure_combat_layers()
	_setup_animator()
	if hitbox != null:
		hitbox.monitoring = false # only active during an ability's active frames
		hitbox.area_entered.connect(_on_hitbox_area_entered)
		hitbox.body_entered.connect(_on_hitbox_body_entered)

func _setup_animator() -> void:
	if not visual_animation_enabled:
		return
	var visual: Node2D = get_node_or_null("Visual") as Node2D
	if visual == null:
		return
	var animator := HeroAnimator.new()
	animator.name = "HeroAnimator"
	add_child(animator)
	animator.setup(self, visual)

## Puts the body/hurtbox on this hero's team layer and the hitbox on the
## dedicated hitbox layer with an enemy-team mask, so attacks reach enemy
## minions/heroes/structures but never allies.
func _configure_combat_layers() -> void:
	var own_bit: int = LAYER_TEAM_A if team == MatchState.Team.TEAM_A else LAYER_TEAM_B
	var enemy_bit: int = LAYER_TEAM_B if team == MatchState.Team.TEAM_A else LAYER_TEAM_A
	set_collision_layer_value(own_bit, true)
	set_collision_mask_value(LAYER_TEAM_A, true)
	set_collision_mask_value(LAYER_TEAM_B, true)
	set_collision_mask_value(LAYER_STRUCTURES, true)
	if hurtbox != null:
		hurtbox.set_collision_layer_value(own_bit, true)
	if hitbox != null:
		hitbox.set_collision_layer_value(LAYER_HITBOX, true)
		hitbox.set_collision_mask_value(enemy_bit, true)
		hitbox.set_collision_mask_value(LAYER_STRUCTURES, true)

func _physics_process(delta: float) -> void:
	match state:
		State.HIT:
			_hitstun_timer -= delta
			if _hitstun_timer <= 0.0:
				_set_state(State.IDLE)
		State.CASTING:
			_process_ability_frames(delta)
		State.DEAD:
			return
		_:
			if is_player_controlled:
				_handle_player_movement()
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if not is_player_controlled or state == State.DEAD:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).physical_keycode:
			KEY_Q:
				_on_skill_pressed(0)
			KEY_E:
				_on_skill_pressed(1)
			KEY_R:
				_on_skill_pressed(2)
			KEY_F:
				_on_skill_pressed(3)

## Default skill mapping: Q/E/R/F cast skill_1/skill_2/skill_3/ultimate.
## Projectile (SKILLSHOT) and AOE abilities are handled generically by the
## frame-data timeline, so a data-only ranged/mage hero needs NO controller
## subclass. Heroes with bespoke behavior (Kael, Bastion, Monk, Machinist)
## override this.
func _on_skill_pressed(slot: int) -> void:
	if hero_definition == null:
		return
	var abilities: Array = [
		hero_definition.skill_1,
		hero_definition.skill_2,
		hero_definition.skill_3,
		hero_definition.ultimate,
	]
	if slot < 0 or slot >= abilities.size():
		return
	cast_ability(abilities[slot])

func _handle_player_movement() -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		direction.y += 1.0
	if direction.length() > 0.01:
		direction = direction.normalized()
		facing = direction
		velocity = direction * move_speed * get_move_speed_multiplier()
		_set_state(State.WALK)
	else:
		velocity = Vector2.ZERO
		_set_state(State.IDLE)

func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(new_state)

## Entry point for playing an ability; drives the frame-data timeline
## (startup -> active -> recovery) and toggles the hitbox on/off exactly
## during the active window.
func cast_ability(ability: AbilityDefinition) -> void:
	if ability == null or state == State.DEAD or state == State.CASTING:
		return
	if is_on_cooldown(ability):
		return
	_cooldowns[ability.ability_id] = ability.cooldown_sec
	_active_ability = ability
	_ability_phase = "startup"
	_ability_frame_timer = ability.startup_frames / float(Engine.physics_ticks_per_second)
	_set_state(State.CASTING)

func _process(delta: float) -> void:
	for ability_id in _cooldowns.keys():
		if _cooldowns[ability_id] > 0.0:
			_cooldowns[ability_id] = max(0.0, _cooldowns[ability_id] - delta)
	_advance_statuses(delta)

# --------------------------------------------------------------------------
# Status effects
# --------------------------------------------------------------------------

func apply_status(definition: StatusEffectDefinition, _source: Node = null) -> void:
	if definition == null:
		return
	for status in _statuses:
		if status.definition.effect_id == definition.effect_id:
			match definition.stack_behavior:
				StatusEffectDefinition.StackBehavior.REFRESH_DURATION:
					status.refresh()
				StatusEffectDefinition.StackBehavior.STACK_INDEPENDENTLY:
					if status.stacks < definition.max_stacks:
						status.stacks += 1
						status.refresh()
				StatusEffectDefinition.StackBehavior.IGNORE_NEW:
					pass
			return
	_statuses.append(ActiveStatus.new(definition))

func remove_status(effect_id: StringName) -> void:
	for i in range(_statuses.size() - 1, -1, -1):
		if _statuses[i].definition.effect_id == effect_id:
			_statuses.remove_at(i)

func has_status(effect_id: StringName) -> bool:
	for status in _statuses:
		if status.definition.effect_id == effect_id:
			return true
	return false

func get_status_count() -> int:
	return _statuses.size()

func get_status_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for status in _statuses:
		ids.append(status.definition.effect_id)
	return ids

func get_move_speed_multiplier() -> float:
	return _status_multiplier("move_speed_mult")

func get_damage_taken_multiplier() -> float:
	return _status_multiplier("damage_taken_mult")

func get_damage_dealt_multiplier() -> float:
	return _status_multiplier("damage_dealt_mult")

## Multiplicative across active statuses (stacks affect only periodic ticks,
## not the multipliers -- stacking a slow must not cancel itself out).
func _status_multiplier(field: String) -> float:
	var mult: float = 1.0
	for status in _statuses:
		mult *= float(status.definition.get(field))
	return mult

func _advance_statuses(delta: float) -> void:
	for i in range(_statuses.size() - 1, -1, -1):
		var status: ActiveStatus = _statuses[i]
		var ticked: bool = status.advance(delta)
		if ticked and status.definition.hp_regen_per_tick != 0.0:
			var amount: float = status.definition.hp_regen_per_tick * status.stacks
			if amount > 0.0:
				heal(amount)
			else:
				# Damage over time: applied directly (no hitstun/flash) so a
				# burn tick doesn't stun-lock the target.
				current_hp = maxf(0.0, current_hp - (-amount))
				if current_hp <= 0.0:
					_die()
		if status.is_expired():
			_statuses.remove_at(i)

func is_on_cooldown(ability: AbilityDefinition) -> bool:
	if ability == null:
		return false
	return _cooldowns.get(ability.ability_id, 0.0) > 0.0

func get_cooldown_remaining(ability: AbilityDefinition) -> float:
	if ability == null:
		return 0.0
	return _cooldowns.get(ability.ability_id, 0.0)

func _process_ability_frames(delta: float) -> void:
	if _active_ability == null:
		_set_state(State.IDLE)
		return
	_ability_frame_timer -= delta
	if _ability_frame_timer > 0.0:
		return
	match _ability_phase:
		"startup":
			_ability_phase = "active"
			_ability_frame_timer = _active_ability.active_frames / float(Engine.physics_ticks_per_second)
			if _active_ability.cast_type == AbilityDefinition.CastType.SKILLSHOT:
				# Ranged/magic abilities fire a projectile instead of using
				# a melee hitbox.
				_spawn_projectile(_active_ability)
			elif _active_ability.cast_type == AbilityDefinition.CastType.AOE:
				_apply_aoe(_active_ability)
			elif hitbox != null:
				hitbox.monitoring = true
		"active":
			_ability_phase = "recovery"
			_ability_frame_timer = _active_ability.recovery_frames / float(Engine.physics_ticks_per_second)
			if hitbox != null:
				hitbox.monitoring = false
		"recovery":
			_active_ability = null
			_set_state(State.IDLE)

## Fires a configured Projectile from the ability's projectile_* fields.
func _spawn_projectile(ability: AbilityDefinition) -> void:
	var projectile: Projectile = ProjectileScene.instantiate() as Projectile
	projectile.team = team
	projectile.direction = facing
	projectile.damage = ability.base_damage * get_damage_dealt_multiplier()
	projectile.speed = ability.projectile_speed
	projectile.max_range = ability.projectile_max_range
	projectile.pierce = ability.projectile_pierce
	projectile.color = ability.projectile_color
	projectile.status_to_apply = ability.status_effect
	projectile.caster = self
	projectile.global_position = global_position + facing * 24.0
	get_parent().add_child(projectile)

## Damages every enemy (hero/minion/structure) within the ability's radius,
## optionally applying its on-hit status. Used by cast_type == AOE.
func _apply_aoe(ability: AbilityDefinition) -> void:
	var radius: float = ability.radius if ability.radius > 0.0 else 120.0
	var damage: float = ability.base_damage * get_damage_dealt_multiplier()
	for group in ["characters", "minions", "structures"]:
		for node in get_tree().get_nodes_in_group(group):
			if node == self:
				continue
			var node_team: Variant = node.get("team")
			if node_team != null and int(node_team) == int(team):
				continue # never damage allies
			var node_position: Variant = node.get("global_position")
			if node_position == null:
				continue
			if global_position.distance_to(node_position) > radius:
				continue
			if not node.has_method("take_damage"):
				continue
			node.call("take_damage", damage, self)
			if ability.status_effect != null and node.has_method("apply_status"):
				node.call("apply_status", ability.status_effect, self)

func _on_hitbox_area_entered(area: Area2D) -> void:
	_apply_hit_to(area.get_parent())

func _on_hitbox_body_entered(body: Node2D) -> void:
	_apply_hit_to(body)

func _apply_hit_to(target: Node) -> void:
	if target == null or target == self or _active_ability == null:
		return
	# Never damage allies: anything with a matching `team` property is friendly.
	var target_team: Variant = target.get("team")
	if target_team != null and int(target_team) == int(team):
		return
	if target.has_method("take_damage"):
		var damage: float = _active_ability.base_damage * get_damage_dealt_multiplier()
		_apply_hitstop(_active_ability.hitstop_frames)
		target.call("take_damage", damage, self)
		hit_landed.emit(target, damage)

## Global hit-stop: briefly slows Engine.time_scale on a big hit for
## "juice", then restores it in real (unscaled) time via
## ignore_time_scale=true on the timer.
func _apply_hitstop(frames: int) -> void:
	if frames <= 0:
		return
	var duration_sec: float = frames / float(Engine.physics_ticks_per_second)
	Engine.time_scale = 0.05
	get_tree().create_timer(duration_sec, true, false, true).timeout.connect(
		func() -> void: Engine.time_scale = 1.0
	)

func take_damage(amount: float, _source: Node = null) -> void:
	if state == State.DEAD or _block_active:
		return
	current_hp = max(0.0, current_hp - amount * get_damage_taken_multiplier())
	if current_hp <= 0.0:
		_die()
	else:
		_hitstun_timer = 0.2
		_set_state(State.HIT)

func _die() -> void:
	_set_state(State.DEAD)
	died.emit()

func heal(amount: float) -> void:
	if state == State.DEAD or amount <= 0.0:
		return
	current_hp = minf(max_hp, current_hp + amount)

func is_alive() -> bool:
	return state != State.DEAD

## Lowest-HP living ally (including self) within `radius` world units.
## Shared utility: Monk's heals use it now; Paladin/Flora will later.
func lowest_hp_ally(radius: float) -> CharacterController:
	var best: CharacterController = null
	var best_ratio: float = INF
	for node in get_tree().get_nodes_in_group("characters"):
		var ally := node as CharacterController
		if ally == null or ally.team != team or not ally.is_alive():
			continue
		if global_position.distance_to(ally.global_position) > radius:
			continue
		var ratio: float = ally.current_hp / maxf(1.0, ally.max_hp)
		if ratio < best_ratio:
			best_ratio = ratio
			best = ally
	return best

## All living allies within `radius`. Self is excluded unless include_self.
func allies_in_radius(radius: float, include_self: bool = false) -> Array[CharacterController]:
	var result: Array[CharacterController] = []
	for node in get_tree().get_nodes_in_group("characters"):
		var ally := node as CharacterController
		if ally == null or ally.team != team or not ally.is_alive():
			continue
		if ally == self and not include_self:
			continue
		if global_position.distance_to(ally.global_position) <= radius:
			result.append(ally)
	return result

func set_blocking(active: bool) -> void:
	_block_active = active
	if active:
		_set_state(State.BLOCK)
	elif state == State.BLOCK:
		_set_state(State.IDLE)

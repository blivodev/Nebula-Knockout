extends GutTest
## Covers the heroes' implemented unique mechanics:
##   Kael      - Riposte parry/counter
##   Bastion   - Bulwark Wall spawn
##   Monk      - Flowing Palm heal + Harmonic Convergence AOE heal
##   Machinist - Scout Drone deploy + Detonate
##   Void      - Nether Step teleport blink
##   Flint     - Quick Shot projectile
## See docs/ARCHITECTURE.md Section 5 for what remains data-only per hero.

const KaelScene: PackedScene = preload("res://entities/heroes/kael/Kael.tscn")
const BastionScene: PackedScene = preload("res://entities/heroes/bastion/Bastion.tscn")
const MonkScene: PackedScene = preload("res://entities/heroes/monk/Monk.tscn")
const MachinistScene: PackedScene = preload("res://entities/heroes/machinist/Machinist.tscn")
const VoidScene: PackedScene = preload("res://entities/heroes/void/Void.tscn")
const FlintScene: PackedScene = preload("res://entities/heroes/flint/Flint.tscn")
const VexScene: PackedScene = preload("res://entities/heroes/vex/Vex.tscn")

func _spawn(scene: PackedScene, team: int, position: Vector2) -> CharacterController:
	var hero: CharacterController = scene.instantiate() as CharacterController
	hero.team = team
	hero.position = position
	add_child_autofree(hero)
	return hero

func after_each() -> void:
	# Walls / projectiles / drones / zones spawned by the cast pipeline are
	# added to the test node without autofree tracking -- clean them up so
	# they can't leak across tests (their SceneTreeTimers only fire when
	# frames advance, which never happens inside a synchronous test).
	var leftovers: Array = []
	for child in get_children():
		if child is BulwarkWall or child is Projectile or child is ScoutDrone or child is GroundZone:
			leftovers.append(child)
	for node in leftovers:
		node.free()

func test_each_starter_hero_uses_its_specialized_controller() -> void:
	var kael: Node = KaelScene.instantiate()
	assert_true(kael is KaelController, "Kael should use KaelController")
	kael.free()
	var bastion: Node = BastionScene.instantiate()
	assert_true(bastion is BastionController, "Bastion should use BastionController")
	bastion.free()
	var monk: Node = MonkScene.instantiate()
	assert_true(monk is MonkController, "Monk should use MonkController")
	monk.free()
	var machinist: Node = MachinistScene.instantiate()
	assert_true(machinist is MachinistController, "Machinist should use MachinistController")
	machinist.free()
	var v: Node = VoidScene.instantiate()
	assert_true(v is VoidController, "Void should use VoidController")
	v.free()
	var f: Node = FlintScene.instantiate()
	assert_true(f is CharacterController, "Flint should use CharacterController")
	f.free()
	var vex: Node = VexScene.instantiate()
	assert_true(vex is VexController, "Vex should use VexController")
	vex.free()

# --- Kael: Riposte ---------------------------------------------------------

func test_kael_riposte_negates_the_hit_and_counters() -> void:
	var kael: KaelController = _spawn(KaelScene, MatchState.Team.TEAM_A, Vector2.ZERO) as KaelController
	var attacker: CharacterController = _spawn(MonkScene, MatchState.Team.TEAM_B, Vector2(60, 0))

	kael.cast_ability(kael.hero_definition.skill_3) # Riposte
	kael._process_ability_frames(1.0) # blow past startup into the active window
	assert_eq(kael._ability_phase, "active", "Riposte should be in its active parry window")

	var hp_before: float = kael.current_hp
	kael.take_damage(100.0, attacker)
	assert_almost_eq(kael.current_hp, hp_before, 0.01, "a parried hit should be fully negated")
	assert_lt(attacker.current_hp, attacker.max_hp, "the attacker should have been countered")

# --- Bastion: Bulwark Wall -------------------------------------------------

func test_bastion_bulwark_wall_spawns_a_wall_in_front() -> void:
	var bastion: BastionController = _spawn(
		BastionScene, MatchState.Team.TEAM_A, Vector2.ZERO
	) as BastionController
	bastion.facing = Vector2.RIGHT
	bastion.cast_bulwark_wall()

	var wall: BulwarkWall = null
	for child in bastion.get_parent().get_children():
		if child is BulwarkWall:
			wall = child
	assert_not_null(wall, "Bulwark Wall should spawn a BulwarkWall node")
	if wall != null:
		assert_gt(wall.position.x, bastion.position.x, "the wall should spawn in front of Bastion")

# --- Monk: heals -----------------------------------------------------------

func test_monk_flowing_palm_heals_the_lowest_hp_ally() -> void:
	var healer: MonkController = _spawn(
		MonkScene, MatchState.Team.TEAM_A, Vector2.ZERO
	) as MonkController
	var ally: CharacterController = _spawn(MonkScene, MatchState.Team.TEAM_A, Vector2(50, 0))
	ally.current_hp = 100.0

	healer.cast_skill_1()
	assert_gt(ally.current_hp, 100.0, "the damaged ally should have been healed")
	assert_almost_eq(
		ally.current_hp, 160.0, 0.01, "Flowing Palm should restore its base_damage (60) as HP"
	)

func test_monk_ultimate_heals_all_nearby_allies() -> void:
	var healer: MonkController = _spawn(
		MonkScene, MatchState.Team.TEAM_A, Vector2.ZERO
	) as MonkController
	var ally_a: CharacterController = _spawn(MonkScene, MatchState.Team.TEAM_A, Vector2(40, 0))
	var ally_b: CharacterController = _spawn(MonkScene, MatchState.Team.TEAM_A, Vector2(0, 40))
	ally_a.current_hp = 200.0
	ally_b.current_hp = 300.0

	healer.cast_ultimate()
	assert_gt(ally_a.current_hp, 200.0, "ally A should have been healed by the ultimate")
	assert_gt(ally_b.current_hp, 300.0, "ally B should have been healed by the ultimate")

# --- Machinist: drone ------------------------------------------------------

func test_machinist_deploy_then_detonate_damages_enemy() -> void:
	var machinist: MachinistController = _spawn(
		MachinistScene, MatchState.Team.TEAM_A, Vector2.ZERO
	) as MachinistController
	machinist.facing = Vector2.RIGHT
	machinist.deploy_drone()

	var drone: ScoutDrone = null
	for child in machinist.get_parent().get_children():
		if child is ScoutDrone:
			drone = child
	assert_not_null(drone, "Scout Drone should deploy a drone")
	if drone == null:
		return

	var enemy: CharacterController = _spawn(MonkScene, MatchState.Team.TEAM_B, Vector2.ZERO)
	enemy.global_position = drone.global_position + Vector2(30, 0)
	var enemy_hp_before: float = enemy.current_hp

	machinist.detonate_drone()
	assert_lt(enemy.current_hp, enemy_hp_before, "an enemy in the blast radius should take damage")

func test_machinist_drone_does_not_damage_allies() -> void:
	var machinist: MachinistController = _spawn(
		MachinistScene, MatchState.Team.TEAM_A, Vector2.ZERO
	) as MachinistController
	machinist.facing = Vector2.RIGHT
	machinist.deploy_drone()

	var drone: ScoutDrone = null
	for child in machinist.get_parent().get_children():
		if child is ScoutDrone:
			drone = child
	if drone == null:
		fail_test("drone failed to deploy")
		return

	var ally: CharacterController = _spawn(MonkScene, MatchState.Team.TEAM_A, Vector2.ZERO)
	ally.global_position = drone.global_position + Vector2(30, 0)
	var ally_hp_before: float = ally.current_hp

	machinist.detonate_drone()
	assert_almost_eq(ally.current_hp, ally_hp_before, 0.01, "the drone must never damage allies")

# --- Void: Nether Step -----------------------------------------------------

func test_void_nether_step_teleports_forward() -> void:
	var void_hero: VoidController = _spawn(VoidScene, MatchState.Team.TEAM_A, Vector2.ZERO) as VoidController
	void_hero.facing = Vector2.RIGHT
	var pos_before: Vector2 = void_hero.position

	void_hero.cast_nether_step()
	void_hero._process_ability_frames(1.0) # active phase
	assert_gt(void_hero.position.x, pos_before.x, "Nether Step should teleport Void forward")
	assert_almost_eq(void_hero.position.x, pos_before.x + VoidController.TELEPORT_DISTANCE, 1.0)

# --- Flint: Quick Shot -----------------------------------------------------

func test_flint_quick_shot_fires_projectile() -> void:
	var flint: CharacterController = _spawn(FlintScene, MatchState.Team.TEAM_A, Vector2.ZERO)
	flint.facing = Vector2.RIGHT
	flint.cast_ability(flint.hero_definition.skill_1)
	flint._process_ability_frames(1.0)

	var proj: Projectile = null
	for child in flint.get_parent().get_children():
		if child is Projectile:
			proj = child
	assert_not_null(proj, "Flint's Quick Shot should spawn a Projectile")

# --- Vex: Shadow Dash & Reaper's Mark --------------------------------------

func test_vex_shadow_dash_moves_forward() -> void:
	var vex: VexController = _spawn(VexScene, MatchState.Team.TEAM_A, Vector2.ZERO) as VexController
	vex.facing = Vector2.RIGHT
	vex.cast_ability(vex.hero_definition.skill_2) # Shadow Dash
	vex._process_ability_frames(1.0) # active phase
	assert_gt(vex.velocity.x, 0.0, "Shadow Dash should set forward dash velocity")

func test_vex_reapers_mark_fires_projectile() -> void:
	var vex: VexController = _spawn(VexScene, MatchState.Team.TEAM_A, Vector2.ZERO) as VexController
	vex.facing = Vector2.RIGHT
	vex.cast_ability(vex.hero_definition.skill_3) # Reaper's Mark
	vex._process_ability_frames(1.0)

	var proj: Projectile = null
	for child in vex.get_parent().get_children():
		if child is Projectile:
			proj = child
	assert_not_null(proj, "Reaper's Mark should spawn a Projectile")

# --- Bastion: Guard Stance & Unbreakable ------------------------------------

func test_bastion_guard_stance_halves_damage_and_reflects() -> void:
	var bastion: BastionController = _spawn(
		BastionScene, MatchState.Team.TEAM_A, Vector2.ZERO
	) as BastionController
	var attacker: CharacterController = _spawn(MonkScene, MatchState.Team.TEAM_B, Vector2(60, 0))

	bastion.cast_ability(bastion.hero_definition.skill_3) # Guard Stance (CHANNEL)
	bastion._process_ability_frames(1.0) # into the active window
	assert_eq(bastion._ability_phase, "active", "Guard Stance should be channeling")

	var hp_before: float = bastion.current_hp
	var attacker_hp: float = attacker.current_hp
	bastion.take_damage(100.0, attacker)
	assert_almost_eq(bastion.current_hp, hp_before - 50.0, 0.01, "Guard Stance should halve incoming damage")
	assert_almost_eq(attacker.current_hp, attacker_hp - 25.0, 0.01, "the attacker should take 25% of the raw hit as reflect")

func test_bastion_unbreakable_cuts_damage_and_nullifies_knockback() -> void:
	var bastion: BastionController = _spawn(
		BastionScene, MatchState.Team.TEAM_A, Vector2.ZERO
	) as BastionController
	bastion.cast_ability(bastion.hero_definition.ultimate) # Unbreakable (SELF)
	bastion._process_ability_frames(1.0)
	assert_eq(bastion._ability_phase, "active", "Unbreakable should be active")

	var hp_before: float = bastion.current_hp
	bastion.take_damage(100.0, null, Vector2(300.0, 0.0))
	assert_almost_eq(bastion.current_hp, hp_before - 20.0, 0.01, "Unbreakable should cut damage to 20%")
	assert_eq(bastion.velocity, Vector2.ZERO, "Unbreakable grants total knockback immunity")

func test_bastion_stances_do_not_block_attacks_when_not_active() -> void:
	var bastion: BastionController = _spawn(
		BastionScene, MatchState.Team.TEAM_A, Vector2.ZERO
	) as BastionController
	var hp_before: float = bastion.current_hp
	bastion.take_damage(100.0, null)
	assert_almost_eq(bastion.current_hp, hp_before - 100.0, 0.01, "no stance active -> full damage")

# --- Bastion: Bulwark Wall team-selective blocking ---------------------------

func test_bulwark_wall_blocks_only_the_enemy_team() -> void:
	var bastion_a: BastionController = _spawn(
		BastionScene, MatchState.Team.TEAM_A, Vector2.ZERO
	) as BastionController
	bastion_a.facing = Vector2.RIGHT
	bastion_a.cast_bulwark_wall()

	var wall_a: BulwarkWall = null
	for child in bastion_a.get_parent().get_children():
		if child is BulwarkWall and child.team == MatchState.Team.TEAM_A:
			wall_a = child
	assert_not_null(wall_a, "TEAM_A wall should spawn")
	if wall_a == null:
		return
	# A TEAM_A-owned wall occupies ONLY the blocks-TEAM_B layer (bit 8).
	assert_true(wall_a.get_collision_layer_value(8), "TEAM_A wall must sit on the wall_blocks_team_b layer")
	assert_false(wall_a.get_collision_layer_value(7), "TEAM_A wall must not sit on the wall_blocks_team_a layer")
	assert_false(wall_a.get_collision_layer_value(6), "walls no longer collide via the shared structures layer")

	# TEAM_A movers mask the blocks-TEAM_A layer only -> pass through allied walls.
	var ally: CharacterController = _spawn(MonkScene, MatchState.Team.TEAM_A, Vector2.ZERO)
	assert_true(ally.get_collision_mask_value(7), "TEAM_A movers must mask the blocks-A wall layer")
	assert_false(ally.get_collision_mask_value(8), "TEAM_A movers must NOT mask the blocks-B wall layer")

	# TEAM_B movers mask the blocks-TEAM_B layer -> blocked by this wall.
	var enemy: CharacterController = _spawn(MonkScene, MatchState.Team.TEAM_B, Vector2.ZERO)
	assert_true(enemy.get_collision_mask_value(8), "TEAM_B movers must mask the blocks-B wall layer")
	assert_false(enemy.get_collision_mask_value(7), "TEAM_B movers must NOT mask the blocks-A wall layer")

func test_enemy_owned_bulwark_wall_occupies_the_opposite_layer() -> void:
	var bastion_b: BastionController = _spawn(
		BastionScene, MatchState.Team.TEAM_B, Vector2.ZERO
	) as BastionController
	bastion_b.facing = Vector2.RIGHT
	bastion_b.cast_bulwark_wall()

	var wall_b: BulwarkWall = null
	for child in bastion_b.get_parent().get_children():
		if child is BulwarkWall and child.team == MatchState.Team.TEAM_B:
			wall_b = child
	assert_not_null(wall_b, "TEAM_B wall should spawn")
	if wall_b == null:
		return
	assert_true(wall_b.get_collision_layer_value(7), "TEAM_B wall must sit on the wall_blocks_team_a layer")
	assert_false(wall_b.get_collision_layer_value(8), "TEAM_B wall must not sit on the wall_blocks_team_b layer")

# --- Kael: Thousand Cuts multi-hit ------------------------------------------

func test_kael_thousand_cuts_lands_every_pulse() -> void:
	var kael: KaelController = _spawn(KaelScene, MatchState.Team.TEAM_A, Vector2.ZERO) as KaelController
	var enemy: CharacterController = _spawn(MonkScene, MatchState.Team.TEAM_B, Vector2(80, 0))
	var hp_before: float = enemy.current_hp

	var ult: AbilityDefinition = kael.hero_definition.ultimate
	kael.current_resource = kael.max_resource # cover the 100 resource cost
	assert_true(kael.cast_ability(ult), "Thousand Cuts should cast with full resource")
	assert_gt(ult.multi_hit_ticks, 0, "Thousand Cuts must be authored as multi-hit")

	# Step the whole cast one physics tick at a time (startup + active).
	var total_frames: int = ult.startup_frames + ult.active_frames
	for i in range(total_frames):
		kael._process_ability_frames(1.0 / 60.0)

	assert_eq(kael._aoe_ticks_done, ult.multi_hit_ticks, "every authored pulse should have landed")
	assert_almost_eq(
		hp_before - enemy.current_hp, ult.base_damage, 0.01,
		"the pulses should sum to the combined base_damage"
	)

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

func _spawn(scene: PackedScene, team: int, position: Vector2) -> CharacterController:
	var hero: CharacterController = scene.instantiate() as CharacterController
	hero.team = team
	hero.position = position
	add_child_autofree(hero)
	return hero

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

extends GutTest
## Verifies the knockback system for melee attacks, projectiles, AOEs, and minions.

const KaelScene: PackedScene = preload("res://entities/heroes/kael/Kael.tscn")
const BastionScene: PackedScene = preload("res://entities/heroes/bastion/Bastion.tscn")
const MonkScene: PackedScene = preload("res://entities/heroes/monk/Monk.tscn")
const MinionScene: PackedScene = preload("res://entities/lane_minion/LaneMinion.tscn")
const ProjectileScene: PackedScene = preload("res://entities/projectile/Projectile.tscn")

func _spawn_hero(scene: PackedScene, team: int, pos: Vector2) -> CharacterController:
	var hero: CharacterController = scene.instantiate() as CharacterController
	hero.team = team
	hero.position = pos
	add_child_autofree(hero)
	return hero

func test_direct_take_damage_applies_knockback_velocity() -> void:
	var hero: CharacterController = _spawn_hero(MonkScene, MatchState.Team.TEAM_B, Vector2.ZERO)
	var kb := Vector2(250.0, 0.0)
	hero.take_damage(20.0, null, kb)

	assert_eq(hero.state, CharacterController.State.HIT, "taking damage with knockback should enter HIT state")
	assert_eq(hero.velocity, kb, "velocity should match the knockback vector")

func test_facing_direction_determines_knockback_vector() -> void:
	var attacker: CharacterController = _spawn_hero(KaelScene, MatchState.Team.TEAM_A, Vector2.ZERO)
	var defender: CharacterController = _spawn_hero(MonkScene, MatchState.Team.TEAM_B, Vector2(50, 0))

	# Facing RIGHT -> knockback should push in +X direction
	attacker.facing = Vector2.RIGHT
	attacker.cast_ability(attacker.hero_definition.skill_1) # Wind Slash: knockback_vector = Vector2(220, 0)
	attacker._apply_hit_to(defender)

	assert_gt(defender.velocity.x, 0.0, "knockback when facing right should push target right")
	var scale_r: float = 1.0 + attacker.hero_definition.skill_1.knockback_scaling * (1.0 - (defender.current_hp / defender.max_hp))
	assert_almost_eq(defender.velocity.x, 220.0 * scale_r, 0.1)

	# Facing LEFT -> knockback should push in -X direction
	defender.velocity = Vector2.ZERO
	defender.current_hp = defender.max_hp
	attacker.facing = Vector2.LEFT
	attacker._apply_hit_to(defender)

	assert_lt(defender.velocity.x, 0.0, "knockback when facing left should push target left")
	var scale_l: float = 1.0 + attacker.hero_definition.skill_1.knockback_scaling * (1.0 - (defender.current_hp / defender.max_hp))
	assert_almost_eq(defender.velocity.x, -220.0 * scale_l, 0.1)

func test_bastion_shield_bash_applies_heavy_knockback() -> void:
	var bastion: BastionController = _spawn_hero(BastionScene, MatchState.Team.TEAM_A, Vector2.ZERO) as BastionController
	var target: CharacterController = _spawn_hero(MonkScene, MatchState.Team.TEAM_B, Vector2(50, 0))

	bastion.facing = Vector2.RIGHT
	bastion.cast_ability(bastion.hero_definition.skill_1) # Shield Bash: knockback_vector = Vector2(340, 0)
	bastion._apply_hit_to(target)

	var scale_b: float = 1.0 + bastion.hero_definition.skill_1.knockback_scaling * (1.0 - (target.current_hp / target.max_hp))
	assert_almost_eq(target.velocity.x, 340.0 * scale_b, 0.1, "Shield Bash should apply scaled 340 knockback")

func test_knockback_scaling_increases_impulse_at_low_hp() -> void:
	var attacker: CharacterController = _spawn_hero(KaelScene, MatchState.Team.TEAM_A, Vector2.ZERO)
	attacker.hero_definition.skill_1.knockback_scaling = 1.0

	var full_hp_target: CharacterController = _spawn_hero(MonkScene, MatchState.Team.TEAM_B, Vector2(50, 0))
	var low_hp_target: CharacterController = _spawn_hero(MonkScene, MatchState.Team.TEAM_B, Vector2(50, 50))
	low_hp_target.current_hp = low_hp_target.max_hp * 0.2 # 20% HP remaining

	attacker.facing = Vector2.RIGHT
	attacker.cast_ability(attacker.hero_definition.skill_1)

	attacker._apply_hit_to(full_hp_target)
	attacker._apply_hit_to(low_hp_target)

	assert_gt(low_hp_target.velocity.x, full_hp_target.velocity.x, "damaged target should receive scaled knockback")

func test_projectile_applies_knockback_on_hit() -> void:
	var proj: Projectile = ProjectileScene.instantiate() as Projectile
	proj.team = MatchState.Team.TEAM_A
	proj.direction = Vector2.RIGHT
	proj.knockback_vector = Vector2(180.0, 0.0)
	proj.damage = 30.0
	add_child_autofree(proj)

	var target: CharacterController = _spawn_hero(MonkScene, MatchState.Team.TEAM_B, Vector2(20, 0))
	proj._hit(target)

	assert_almost_eq(target.velocity.x, 180.0, 0.1, "projectile hit should apply knockback")

func test_lane_minion_receives_knockback() -> void:
	var minion: LaneMinion = MinionScene.instantiate() as LaneMinion
	minion.team = MatchState.Team.TEAM_B
	add_child_autofree(minion)

	var kb := Vector2(200.0, 0.0)
	minion.take_damage(25.0, null, kb)

	assert_eq(minion.velocity, kb, "minion should receive knockback velocity")

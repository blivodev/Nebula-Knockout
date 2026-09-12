extends GutTest
## Covers the projectile system + Pyra's SKILLSHOT/AOE fire kit.

const PyraScene: PackedScene = preload("res://entities/heroes/pyra/Pyra.tscn")
const MonkScene: PackedScene = preload("res://entities/heroes/monk/Monk.tscn")

func _spawn(scene: PackedScene, team: int, position: Vector2) -> CharacterController:
	var hero: CharacterController = scene.instantiate() as CharacterController
	hero.team = team
	hero.position = position
	add_child_autofree(hero)
	return hero

func _find_projectile(parent: Node) -> Projectile:
	for child in parent.get_children():
		if child is Projectile:
			return child
	return null

func test_ember_bolt_fires_a_projectile() -> void:
	var pyra: CharacterController = _spawn(PyraScene, MatchState.Team.TEAM_A, Vector2.ZERO)
	pyra.facing = Vector2.RIGHT
	pyra.cast_ability(pyra.hero_definition.skill_1) # SKILLSHOT
	pyra._process_ability_frames(1.0) # advance into the active phase
	assert_not_null(_find_projectile(pyra.get_parent()), "Ember Bolt should fire a projectile")

func test_projectile_hits_enemy_and_applies_burn() -> void:
	var pyra: CharacterController = _spawn(PyraScene, MatchState.Team.TEAM_A, Vector2.ZERO)
	pyra.facing = Vector2.RIGHT
	var enemy: CharacterController = _spawn(MonkScene, MatchState.Team.TEAM_B, Vector2(220, 0))

	pyra.cast_ability(pyra.hero_definition.skill_1)
	await wait_physics_frames(45) # startup + travel time

	assert_lt(enemy.current_hp, enemy.max_hp, "the enemy should have been hit by the bolt")
	assert_true(enemy.has_status(&"burn"), "the bolt should have applied burn")

func test_projectile_does_not_hit_allies() -> void:
	var pyra: CharacterController = _spawn(PyraScene, MatchState.Team.TEAM_A, Vector2.ZERO)
	pyra.facing = Vector2.RIGHT
	var ally: CharacterController = _spawn(MonkScene, MatchState.Team.TEAM_A, Vector2(220, 0))
	var ally_hp_before: float = ally.current_hp

	pyra.cast_ability(pyra.hero_definition.skill_1)
	await wait_physics_frames(45)

	assert_almost_eq(ally.current_hp, ally_hp_before, 0.01, "projectiles must not damage allies")

func test_flame_nova_aoe_damages_nearby_enemy() -> void:
	var pyra: CharacterController = _spawn(PyraScene, MatchState.Team.TEAM_A, Vector2.ZERO)
	var enemy: CharacterController = _spawn(MonkScene, MatchState.Team.TEAM_B, Vector2(120, 0))
	var enemy_hp_before: float = enemy.current_hp

	pyra.cast_ability(pyra.hero_definition.skill_2) # AOE
	pyra._process_ability_frames(1.0) # into the active phase

	assert_lt(enemy.current_hp, enemy_hp_before, "Flame Nova should damage an enemy inside its radius")
	assert_true(enemy.has_status(&"burn"), "Flame Nova should apply burn")

func test_flame_nova_does_not_damage_distant_enemy() -> void:
	var pyra: CharacterController = _spawn(PyraScene, MatchState.Team.TEAM_A, Vector2.ZERO)
	var enemy: CharacterController = _spawn(MonkScene, MatchState.Team.TEAM_B, Vector2(600, 0))
	var enemy_hp_before: float = enemy.current_hp

	pyra.cast_ability(pyra.hero_definition.skill_2)
	pyra._process_ability_frames(1.0)

	assert_almost_eq(enemy.current_hp, enemy_hp_before, 0.01, "an out-of-range enemy should be untouched")

extends GutTest
## Verifies persistent GroundZone behavior (spawned by ZONE abilities like
## Pyra's Cinder Field) and the ability-data-driven zone pipeline.

const PyraScene: PackedScene = preload("res://entities/heroes/pyra/Pyra.tscn")
const MonkScene: PackedScene = preload("res://entities/heroes/monk/Monk.tscn")
const GroundZoneScene: PackedScene = preload("res://entities/ground_zone/GroundZone.tscn")

func _spawn(scene: PackedScene, team: int, position: Vector2) -> CharacterController:
	var hero: CharacterController = scene.instantiate() as CharacterController
	hero.team = team
	hero.position = position
	add_child_autofree(hero)
	return hero

func after_each() -> void:
	# Zones spawned by the cast pipeline are added to the test node's parent
	# without autofree tracking -- clean them up so they can't leak across
	# tests with stale (freed) source references.
	var leftovers: Array = []
	for child in get_children():
		if child is GroundZone:
			leftovers.append(child)
	for zone in leftovers:
		zone.free()

func _find_zone(spawner: Node) -> GroundZone:
	for child in spawner.get_parent().get_children():
		if child is GroundZone and child.source == spawner:
			return child
	return null

func test_cinder_field_spawns_a_persistent_zone() -> void:
	var pyra: CharacterController = _spawn(PyraScene, MatchState.Team.TEAM_A, Vector2.ZERO)
	pyra.facing = Vector2.RIGHT
	pyra.cast_ability(pyra.hero_definition.skill_3) # Cinder Field (ZONE)
	for i in range(12):
		pyra._process_ability_frames(1.0 / 60.0) # through startup into active

	var zone: GroundZone = _find_zone(pyra)
	assert_not_null(zone, "Cinder Field should spawn a GroundZone")
	if zone == null:
		return
	assert_almost_eq(zone.radius, 220.0, 0.01, "zone radius should come from the ability data")
	assert_eq(zone.damage_per_tick, 12.0, "zone per-tick damage should come from base_damage")
	assert_almost_eq(zone.lifetime_sec, 3.0, 0.001, "zone lifetime should be active_frames in seconds")
	assert_eq(zone.team, MatchState.Team.TEAM_A)

func test_zone_ticks_damage_enemies_and_apply_status() -> void:
	var pyra: CharacterController = _spawn(PyraScene, MatchState.Team.TEAM_A, Vector2.ZERO)
	pyra.cast_ability(pyra.hero_definition.skill_3)
	for i in range(12):
		pyra._process_ability_frames(1.0 / 60.0)
	var zone: GroundZone = _find_zone(pyra)
	assert_not_null(zone, "Cinder Field should spawn a GroundZone")
	if zone == null:
		return

	var enemy: CharacterController = _spawn(MonkScene, MatchState.Team.TEAM_B, Vector2(50, 0))
	var enemy_hp: float = enemy.current_hp
	zone._tick()
	assert_almost_eq(enemy.current_hp, enemy_hp - zone.damage_per_tick, 0.01, "enemies inside the zone should take per-tick damage")
	assert_true(enemy.has_status(&"burn"), "the zone should re-apply its on-tick status")

func test_zone_never_damages_allies() -> void:
	var zone: GroundZone = GroundZoneScene.instantiate() as GroundZone
	zone.team = MatchState.Team.TEAM_A
	zone.radius = 220.0
	zone.damage_per_tick = 12.0
	add_child_autofree(zone)

	var ally: CharacterController = _spawn(MonkScene, MatchState.Team.TEAM_A, Vector2(50, 0))
	var ally_hp: float = ally.current_hp
	zone._tick()
	assert_almost_eq(ally.current_hp, ally_hp, 0.01, "allies must never be damaged by the zone")

func test_zone_skips_targets_outside_radius() -> void:
	var zone: GroundZone = GroundZoneScene.instantiate() as GroundZone
	zone.team = MatchState.Team.TEAM_A
	zone.radius = 100.0
	zone.damage_per_tick = 12.0
	add_child_autofree(zone)

	var far_enemy: CharacterController = _spawn(MonkScene, MatchState.Team.TEAM_B, Vector2(300, 0))
	var hp_before: float = far_enemy.current_hp
	zone._tick()
	assert_almost_eq(far_enemy.current_hp, hp_before, 0.01, "targets outside the radius must not be ticked")

func test_zone_expires_after_lifetime() -> void:
	var zone: GroundZone = GroundZoneScene.instantiate() as GroundZone
	zone.team = MatchState.Team.TEAM_A
	zone.lifetime_sec = 3.0
	zone.tick_interval = 0.5
	add_child_autofree(zone)

	zone._process(zone.lifetime_sec)
	assert_true(zone.is_queued_for_deletion(), "the zone should queue_free once its lifetime expires")

func test_zone_ticks_on_interval_not_every_frame() -> void:
	var zone: GroundZone = GroundZoneScene.instantiate() as GroundZone
	zone.team = MatchState.Team.TEAM_A
	zone.tick_interval = 0.5
	zone.lifetime_sec = 10.0
	add_child_autofree(zone)

	var enemy: CharacterController = _spawn(MonkScene, MatchState.Team.TEAM_B, Vector2(10, 0))
	var hp_before: float = enemy.current_hp
	# 0.2s of frames (below the 0.5s interval) must not tick yet.
	for i in range(12):
		zone._process(1.0 / 60.0)
	assert_almost_eq(enemy.current_hp, hp_before, 0.01, "no damage before the first tick interval elapses")
	# Cross the interval boundary.
	zone._process(0.3)
	assert_lt(enemy.current_hp, hp_before, "damage should land when the tick interval elapses")

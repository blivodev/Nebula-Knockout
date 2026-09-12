extends GutTest
## Verifies resource (mana/energy) enforcement, passive regeneration, and cast range validation.

const PyraScene: PackedScene = preload("res://entities/heroes/pyra/Pyra.tscn")
const KaelScene: PackedScene = preload("res://entities/heroes/kael/Kael.tscn")
const VoidScene: PackedScene = preload("res://entities/heroes/void/Void.tscn")

func _spawn(scene: PackedScene) -> CharacterController:
	var hero: CharacterController = scene.instantiate() as CharacterController
	add_child_autofree(hero)
	return hero

func test_hero_initializes_with_full_resource() -> void:
	var hero: CharacterController = _spawn(PyraScene)
	assert_gt(hero.max_resource, 0.0, "max resource should be positive")
	assert_almost_eq(hero.current_resource, hero.max_resource, 0.01, "hero should start with full resource")

func test_casting_ultimate_deducts_resource_cost() -> void:
	var hero: CharacterController = _spawn(PyraScene)
	var ult: AbilityDefinition = hero.hero_definition.ultimate
	assert_eq(ult.resource_cost, 100.0, "Pyra ultimate costs 100 resource")

	hero.current_resource = 100.0
	var success: bool = hero.cast_ability(ult)

	assert_true(success, "cast should succeed with exact resource available")
	assert_almost_eq(hero.current_resource, 0.0, 0.01, "resource should be deducted")
	assert_eq(hero.state, CharacterController.State.CASTING)

func test_casting_rejected_when_insufficient_resource() -> void:
	var hero: CharacterController = _spawn(PyraScene)
	var ult: AbilityDefinition = hero.hero_definition.ultimate

	hero.current_resource = 50.0 # Not enough for 100 cost
	var success: bool = hero.cast_ability(ult)

	assert_false(success, "cast should fail when lacking resource")
	assert_almost_eq(hero.current_resource, 50.0, 0.01, "resource should not be deducted on failed cast")
	assert_ne(hero.state, CharacterController.State.CASTING, "should not enter CASTING state")
	assert_false(hero.is_on_cooldown(ult), "cooldown should not be triggered on failed cast")

func test_passive_resource_regen_restores_resource() -> void:
	var hero: CharacterController = _spawn(PyraScene)
	hero.current_resource = 10.0
	var regen_rate: float = hero.hero_definition.base_resource_regen # 5.0 per sec

	hero.gain_resource(regen_rate * 2.0) # 2 seconds of regen
	assert_almost_eq(hero.current_resource, 20.0, 0.01, "passive regen should increase resource")

	# Clamping at max
	hero.gain_resource(1000.0)
	assert_almost_eq(hero.current_resource, hero.max_resource, 0.01, "resource should clamp at max")

func test_cast_range_validation_succeeds_in_range() -> void:
	var hero: CharacterController = _spawn(KaelScene)
	hero.global_position = Vector2.ZERO
	var skill1: AbilityDefinition = hero.hero_definition.skill_1 # Wind Slash: cast_range = 140.0

	var in_range_target := Vector2(100.0, 0.0)
	assert_true(hero.is_in_cast_range(skill1, in_range_target), "target within 140 should be in range")

	var cast_ok: bool = hero.cast_ability(skill1, in_range_target)
	assert_true(cast_ok, "cast should succeed when in range")
	assert_eq(hero.state, CharacterController.State.CASTING)

func test_cast_range_validation_fails_out_of_range() -> void:
	var hero: CharacterController = _spawn(KaelScene)
	hero.global_position = Vector2.ZERO
	var skill1: AbilityDefinition = hero.hero_definition.skill_1 # Wind Slash: cast_range = 140.0

	var out_of_range_target := Vector2(300.0, 0.0)
	assert_false(hero.is_in_cast_range(skill1, out_of_range_target), "target beyond 140 should be out of range")

	var cast_ok: bool = hero.cast_ability(skill1, out_of_range_target)
	assert_false(cast_ok, "cast should fail when out of range")
	assert_ne(hero.state, CharacterController.State.CASTING)
	assert_false(hero.is_on_cooldown(skill1), "cooldown should not trigger on failed cast")

func test_cast_with_target_position_updates_facing() -> void:
	var hero: CharacterController = _spawn(VoidScene)
	hero.global_position = Vector2.ZERO
	hero.facing = Vector2.RIGHT

	var target_left := Vector2(-150.0, 0.0)
	var beam: AbilityDefinition = hero.hero_definition.skill_1 # Void Beam: cast_range = 700.0

	var cast_ok: bool = hero.cast_ability(beam, target_left)
	assert_true(cast_ok, "Void Beam should cast towards target")
	assert_almost_eq(hero.facing.x, -1.0, 0.01, "facing should update towards target position")

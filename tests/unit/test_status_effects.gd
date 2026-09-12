extends GutTest
## Covers the status-effect system (core/ActiveStatus.gd +
## StatusEffectDefinition): apply, refresh, expire, multipliers, and DoT.

const BurnStatus: StatusEffectDefinition = preload("res://statuses/burn.tres")
const SlowStatus: StatusEffectDefinition = preload("res://statuses/slow.tres")
const MonkScene: PackedScene = preload("res://entities/heroes/monk/Monk.tscn")

func _spawn_hero() -> CharacterController:
	var hero: CharacterController = MonkScene.instantiate() as CharacterController
	add_child_autofree(hero)
	return hero

func _make_status(id: StringName, duration: float = 10.0) -> StatusEffectDefinition:
	var status := StatusEffectDefinition.new()
	status.effect_id = id
	status.duration_sec = duration
	return status

func test_apply_and_has_status() -> void:
	var hero: CharacterController = _spawn_hero()
	hero.apply_status(SlowStatus)
	assert_true(hero.has_status(&"slow"))
	assert_eq(hero.get_status_count(), 1)

func test_slow_reduces_move_speed_multiplier() -> void:
	var hero: CharacterController = _spawn_hero()
	hero.apply_status(SlowStatus) # move_speed_mult 0.6
	assert_almost_eq(hero.get_move_speed_multiplier(), 0.6, 0.01)

func test_burn_deals_damage_over_time() -> void:
	var hero: CharacterController = _spawn_hero()
	var hp_before: float = hero.current_hp
	hero.apply_status(BurnStatus)
	hero._advance_statuses(0.6) # burn ticks every 0.5s
	assert_lt(hero.current_hp, hp_before, "burn should have dealt a damage tick")

func test_status_expires_after_its_duration() -> void:
	var hero: CharacterController = _spawn_hero()
	hero.apply_status(SlowStatus) # 2.5s
	hero._advance_statuses(3.0)
	assert_false(hero.has_status(&"slow"), "status should expire after its duration")

func test_reapply_refreshes_rather_than_stacks() -> void:
	var hero: CharacterController = _spawn_hero()
	hero.apply_status(SlowStatus)
	hero._advance_statuses(2.0)
	hero.apply_status(SlowStatus) # REFRESH_DURATION
	assert_eq(hero.get_status_count(), 1, "re-applying must not create a second instance")
	hero._advance_statuses(1.0)
	assert_true(hero.has_status(&"slow"), "duration should have been refreshed")

func test_damage_taken_multiplier_is_multiplicative_across_statuses() -> void:
	var hero: CharacterController = _spawn_hero()
	var a: StatusEffectDefinition = _make_status(&"vuln_a")
	a.damage_taken_mult = 1.5
	var b: StatusEffectDefinition = _make_status(&"vuln_b")
	b.damage_taken_mult = 1.5
	hero.apply_status(a)
	hero.apply_status(b)
	assert_almost_eq(hero.get_damage_taken_multiplier(), 2.25, 0.01)

func test_remove_status() -> void:
	var hero: CharacterController = _spawn_hero()
	hero.apply_status(SlowStatus)
	hero.remove_status(&"slow")
	assert_false(hero.has_status(&"slow"))

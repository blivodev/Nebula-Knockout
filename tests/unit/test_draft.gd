extends GutTest
## Covers the Draft / Character Select screen (docs/ARCHITECTURE.md,
## Gameplay Loop & Match Flow): roster grid, selection, lock-in, team-pick
## recording, the class-aware Suggest, and timer auto-lock.

const DraftScreenScene: PackedScene = preload("res://ui/draft/DraftScreen.tscn")

func before_each() -> void:
	HeroDatabase.reload()
	MatchState.team_a_picks.clear()
	MatchState.team_b_picks.clear()
	MatchState.set_phase(MatchState.Phase.DRAFT)

func _make_draft(team: int = MatchState.Team.TEAM_A, use_timer: bool = false) -> DraftScreen:
	var draft: DraftScreen = DraftScreenScene.instantiate() as DraftScreen
	draft.team = team
	draft.timer_enabled = use_timer
	add_child_autofree(draft)
	return draft

func test_grid_has_one_button_per_hero() -> void:
	var draft: DraftScreen = _make_draft()
	assert_eq(draft.get_hero_button_count(), HeroDatabase.count(), "grid should list every hero")

func test_lock_in_requires_a_selection() -> void:
	var draft: Control = _make_draft()
	assert_false(draft.lock_in(), "cannot lock with no hero selected")
	assert_false(draft.is_locked())

func test_select_then_lock_records_the_pick() -> void:
	var draft: Control = _make_draft()
	draft.select_hero(HeroDatabase.get_hero(&"kael"))
	assert_true(draft.lock_in())
	assert_true(draft.is_locked())
	assert_true(MatchState.team_a_picks.has(&"kael"), "pick should land in Team A")

func test_lock_emits_hero_locked_signal() -> void:
	var draft: Control = _make_draft()
	var hero: HeroDefinition = HeroDatabase.get_hero(&"monk")
	draft.select_hero(hero)
	watch_signals(draft)
	draft.lock_in()
	assert_signal_emitted_with_parameters(draft, "hero_locked", [MatchState.Team.TEAM_A, hero])

func test_cannot_lock_twice() -> void:
	var draft: Control = _make_draft()
	draft.select_hero(HeroDatabase.get_hero(&"kael"))
	assert_true(draft.lock_in())
	assert_false(draft.lock_in(), "a second lock should be rejected")

func test_suggest_avoids_an_already_covered_class() -> void:
	var first: DraftScreen = _make_draft()
	first.select_hero(HeroDatabase.get_hero(&"kael")) # DAMAGE
	first.lock_in()

	var second: DraftScreen = _make_draft()
	var suggested: HeroDefinition = second.suggest_hero()
	assert_not_null(suggested)
	assert_ne(
		suggested.hero_class,
		HeroDefinition.HeroClass.DAMAGE,
		"Suggest should prefer a class the team does not already have"
	)

func test_timer_auto_locks_at_zero() -> void:
	var draft: DraftScreen = DraftScreenScene.instantiate() as DraftScreen
	draft.team = MatchState.Team.TEAM_A
	draft.timer_enabled = true
	draft.draft_seconds = 0.0
	add_child_autofree(draft)
	await wait_process_frames(5)
	assert_true(draft.is_locked(), "draft should auto-lock when the timer expires")
	assert_eq(MatchState.team_a_picks.size(), 1, "auto-lock should still record exactly one pick")

extends GutTest
## Covers the GameRoot match flow: Draft -> Match -> Post-match, and that the
## drafted hero propagates into the arena.

const GameRootScene: PackedScene = preload("res://scenes/GameRoot.tscn")

func before_each() -> void:
	HeroDatabase.reload()
	MatchState.team_a_picks.clear()
	MatchState.team_b_picks.clear()
	MatchState.match_time_sec = 0.0

func _make_root() -> GameRoot:
	var root: GameRoot = GameRootScene.instantiate() as GameRoot
	add_child_autofree(root)
	return root

func _find_draft(root: GameRoot) -> DraftScreen:
	for child in root.get_children():
		if child is DraftScreen:
			return child
	return null

func test_flow_starts_in_draft_with_a_draft_screen() -> void:
	var root: GameRoot = _make_root()
	assert_eq(root.get_phase(), GameRoot.Phase.DRAFT)
	assert_not_null(_find_draft(root), "a DraftScreen should be present in the draft phase")

func test_locking_a_hero_transitions_to_the_match_with_that_hero() -> void:
	var root: GameRoot = _make_root()
	var draft: DraftScreen = _find_draft(root)
	draft.select_hero(HeroDatabase.get_hero(&"bastion"))
	draft.lock_in()
	await wait_process_frames(2)

	assert_eq(root.get_phase(), GameRoot.Phase.MATCH, "locking a hero should start the match")
	var arena: Node = root.get_current()
	assert_true(arena is Node2D, "the match phase should show the arena")
	assert_eq(arena.get("player_hero_id"), &"bastion", "the drafted hero should reach the arena")
	assert_eq(arena.get("enemy_hero_id"), MatchState.team_b_picks[0], "the enemy hero pick should reach the arena")
	assert_not_null(arena.get("_enemy_hero"), "the enemy hero should be spawned in the arena")

func test_match_end_transitions_to_post_match() -> void:
	var root: GameRoot = _make_root()
	var draft: DraftScreen = _find_draft(root)
	draft.select_hero(HeroDatabase.get_hero(&"monk"))
	draft.lock_in()
	await wait_process_frames(2)

	MatchState.end_match(MatchState.Team.TEAM_A)
	await wait_process_frames(2)
	assert_eq(root.get_phase(), GameRoot.Phase.POST_MATCH, "match end should show the summary")

func test_enemy_team_is_auto_filled_on_lock() -> void:
	var root: GameRoot = _make_root()
	var draft: DraftScreen = _find_draft(root)
	draft.select_hero(HeroDatabase.get_hero(&"kael"))
	draft.lock_in()
	assert_eq(MatchState.team_b_picks.size(), 1, "enemy team should be auto-filled with one pick")

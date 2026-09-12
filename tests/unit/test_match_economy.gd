extends GutTest
## Covers MatchEconomy: registration, last-hit gold, and kill-streak bounty
## scaling (docs/ARCHITECTURE.md, Item Shop & Economy).

func before_each() -> void:
	MatchEconomy._gold.clear()
	MatchEconomy._kill_streak.clear()
	MatchEconomy._passive_accum.clear()

func test_register_player_sets_starting_gold() -> void:
	MatchEconomy.register_player(0)
	assert_eq(MatchEconomy.get_gold(0), MatchEconomy.STARTING_GOLD)

func test_minion_last_hit_grants_gold() -> void:
	MatchEconomy.register_player(0)
	MatchEconomy.on_minion_last_hit(0)
	assert_eq(
		MatchEconomy.get_gold(0),
		MatchEconomy.STARTING_GOLD + MatchEconomy.MINION_LAST_HIT_GOLD
	)

func test_kill_bounty_scales_with_victim_streak() -> void:
	MatchEconomy.register_player(0) # killer
	MatchEconomy.register_player(1) # victim, built up a 2-kill streak
	MatchEconomy._kill_streak[1] = 2

	MatchEconomy.on_player_kill(0, 1)

	var expected_bounty: int = (
		MatchEconomy.PLAYER_KILL_BASE_GOLD + 2 * MatchEconomy.PLAYER_KILL_STREAK_BONUS
	)
	assert_eq(MatchEconomy.get_gold(0), MatchEconomy.STARTING_GOLD + expected_bounty)
	assert_eq(MatchEconomy._kill_streak[1], 0, "Victim's streak resets on death")
	assert_eq(MatchEconomy._kill_streak[0], 1, "Killer's streak increments")

func test_spend_gold_fails_when_insufficient() -> void:
	MatchEconomy.register_player(0, 10)
	assert_false(MatchEconomy.spend_gold(0, 9999))
	assert_eq(MatchEconomy.get_gold(0), 10, "Failed spend must not change balance")

extends Node
## Autoload singleton: gold economy (last-hits, neutral camps, kill
## bounties, passive income, buyback). Server-authoritative in the Phase 2
## networked build; for the local prototype this is the direct source of
## truth (see docs/ARCHITECTURE.md).

signal gold_changed(player_id: int, new_amount: int)

const STARTING_GOLD: int = 500
const PASSIVE_GOLD_PER_SEC: float = 2.0
const MINION_LAST_HIT_GOLD: int = 20
const NEUTRAL_CAMP_GOLD: int = 40
const PLAYER_KILL_BASE_GOLD: int = 150
const PLAYER_KILL_STREAK_BONUS: int = 25
const PLAYER_ASSIST_GOLD: int = 60

var _gold: Dictionary = {}          # player_id: int -> gold: int
var _kill_streak: Dictionary = {}   # player_id: int -> streak: int
var _passive_accum: Dictionary = {} # player_id: int -> float seconds accumulator

func register_player(player_id: int, starting_gold: int = STARTING_GOLD) -> void:
	_gold[player_id] = starting_gold
	_kill_streak[player_id] = 0
	_passive_accum[player_id] = 0.0

func get_gold(player_id: int) -> int:
	return _gold.get(player_id, 0)

func _process(delta: float) -> void:
	if MatchState.phase != MatchState.Phase.IN_PROGRESS:
		return
	for player_id in _passive_accum.keys():
		_passive_accum[player_id] += delta
		while _passive_accum[player_id] >= 1.0:
			_passive_accum[player_id] -= 1.0
			add_gold(player_id, PASSIVE_GOLD_PER_SEC)

func add_gold(player_id: int, amount: float) -> void:
	if not _gold.has(player_id):
		register_player(player_id)
	_gold[player_id] += int(round(amount))
	gold_changed.emit(player_id, _gold[player_id])

func spend_gold(player_id: int, amount: int) -> bool:
	if get_gold(player_id) < amount:
		return false
	_gold[player_id] -= amount
	gold_changed.emit(player_id, _gold[player_id])
	return true

func on_minion_last_hit(player_id: int) -> void:
	if player_id < 0:
		return
	if player_id == 0:
		AudioDirector.play_coin()
	add_gold(player_id, MINION_LAST_HIT_GOLD)

func on_neutral_camp_cleared(player_id: int) -> void:
	add_gold(player_id, NEUTRAL_CAMP_GOLD)

## Bounty scales with the victim's current kill streak -- a snowball vs.
## comeback tuning knob, same idea as Dota's bounty rune / LoL's shutdown gold.
func on_player_kill(killer_id: int, victim_id: int) -> void:
	var victim_streak: int = _kill_streak.get(victim_id, 0)
	var bounty: int = PLAYER_KILL_BASE_GOLD + max(0, victim_streak) * PLAYER_KILL_STREAK_BONUS
	add_gold(killer_id, bounty)
	_kill_streak[killer_id] = _kill_streak.get(killer_id, 0) + 1
	_kill_streak[victim_id] = 0

func on_player_assist(player_id: int) -> void:
	add_gold(player_id, PLAYER_ASSIST_GOLD)

func try_buyback(player_id: int) -> bool:
	return spend_gold(player_id, MatchState.buyback_cost())

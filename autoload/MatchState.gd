extends Node
## Autoload singleton: overall match lifecycle, phase, timer, and team
## composition. This is the single source of truth in the local/hotseat
## prototype; in the Phase 2 networked build, only the dedicated server's
## instance of this autoload is authoritative (see docs/ARCHITECTURE.md).

signal phase_changed(new_phase: Phase)
signal match_ended(winning_team: int)

enum Phase { DRAFT, LOADING, IN_PROGRESS, POST_MATCH }
enum Team { TEAM_A = 0, TEAM_B = 1 }

## All mirrored map geometry (bases, towers, jungle camps, the boss) is
## reflected around this world-space X coordinate. Anything mirrored
## should go through mirror_position() rather than being hand-placed on
## both sides, so symmetry is guaranteed by construction.
const MAP_CENTER_X: float = 0.0

var phase: Phase = Phase.DRAFT
var match_time_sec: float = 0.0
var team_a_picks: Array[StringName] = []
var team_b_picks: Array[StringName] = []

func _process(delta: float) -> void:
	if phase == Phase.IN_PROGRESS:
		match_time_sec += delta

func set_phase(new_phase: Phase) -> void:
	if phase == new_phase:
		return
	phase = new_phase
	phase_changed.emit(new_phase)

func end_match(winning_team: int) -> void:
	set_phase(Phase.POST_MATCH)
	match_ended.emit(winning_team)

func mirror_position(pos: Vector2) -> Vector2:
	return Vector2(MAP_CENTER_X * 2.0 - pos.x, pos.y)

## Buyback cost scales with match time (classic MOBA tuning knob to keep
## early buybacks cheap and late-game buybacks a real decision).
func buyback_cost() -> int:
	return int(100 + match_time_sec * 0.8)

class_name GameRoot
extends Node
## Top-level match flow: Draft -> Match -> Post-match -> (Play Again).
## This is the scene the game boots into (project.godot run/main_scene). It
## owns exactly one "current" screen at a time and swaps between them.
##
## See docs/ARCHITECTURE.md, Gameplay Loop & Match Flow.

enum Phase { DRAFT, MATCH, POST_MATCH }

const DraftScreenScene: PackedScene = preload("res://ui/draft/DraftScreen.tscn")
const TestArenaScene: PackedScene = preload("res://maps/test_arena/TestArena.tscn")

var _phase: Phase = Phase.DRAFT
var _current: Node = null
var _player_hero_id: StringName = &"kael"
var _winning_team: int = -1

func _ready() -> void:
	MatchState.match_ended.connect(_on_match_ended)
	_enter_draft()

func get_phase() -> Phase:
	return _phase

func get_current() -> Node:
	return _current

func _clear_current() -> void:
	if _current != null and is_instance_valid(_current):
		_current.queue_free()
	_current = null

# --------------------------------------------------------------------------
# Phase transitions
# --------------------------------------------------------------------------

func _enter_draft() -> void:
	_phase = Phase.DRAFT
	_clear_current()
	AudioDirector.stop_music(0.5)
	MatchState.set_phase(MatchState.Phase.DRAFT)
	MatchState.team_a_picks.clear()
	MatchState.team_b_picks.clear()
	var draft: DraftScreen = DraftScreenScene.instantiate() as DraftScreen
	draft.team = MatchState.Team.TEAM_A
	draft.hero_locked.connect(_on_hero_locked)
	add_child(draft)
	_current = draft

func _on_hero_locked(team: int, hero: HeroDefinition) -> void:
	if team == MatchState.Team.TEAM_A:
		_player_hero_id = hero.hero_id
	_auto_pick_enemy()
	_enter_match()

## Fills the enemy team with a random pick so the composition display means
## something. A real opposing draft / matchmaking is future work.
func _auto_pick_enemy() -> void:
	if not MatchState.team_b_picks.is_empty():
		return
	var all: Array[HeroDefinition] = HeroDatabase.get_all_heroes()
	if not all.is_empty():
		MatchState.team_b_picks.append(all[randi() % all.size()].hero_id)

func _enter_match() -> void:
	_phase = Phase.MATCH
	_clear_current()
	AudioDirector.start_battle_music()
	var arena: Node = TestArenaScene.instantiate()
	arena.player_hero_id = _player_hero_id
	if not MatchState.team_b_picks.is_empty():
		arena.enemy_hero_id = MatchState.team_b_picks[0]
	add_child(arena)
	_current = arena

func _on_match_ended(winning_team: int) -> void:
	_winning_team = winning_team
	AudioDirector.play_victory()
	_enter_post_match()

func _enter_post_match() -> void:
	_phase = Phase.POST_MATCH
	_clear_current()
	var summary: Control = _build_summary()
	add_child(summary)
	_current = summary

# --------------------------------------------------------------------------
# Post-match summary (built in code)
# --------------------------------------------------------------------------

func _build_summary() -> Control:
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.10, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	var player_won: bool = _winning_team == MatchState.Team.TEAM_A
	var result := Label.new()
	result.text = "VICTORY" if player_won else "DEFEAT"
	result.add_theme_font_size_override("font_size", 56)
	result.add_theme_color_override(
		"font_color",
		Color(0.55, 0.9, 0.6) if player_won else Color(0.95, 0.5, 0.5)
	)
	box.add_child(result)

	var detail := Label.new()
	detail.text = "Winning team: %s     Match time: %ds" % [
		"Team A" if player_won else "Team B", int(MatchState.match_time_sec)
	]
	detail.add_theme_font_size_override("font_size", 20)
	box.add_child(detail)

	var again := Button.new()
	again.text = "Play Again"
	again.custom_minimum_size = Vector2(260, 56)
	again.pressed.connect(_enter_draft)
	box.add_child(again)

	return panel

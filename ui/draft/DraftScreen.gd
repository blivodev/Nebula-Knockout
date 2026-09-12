class_name DraftScreen
extends Control
## Pre-match Character Select / Draft screen (docs/ARCHITECTURE.md, Gameplay
## Loop & Match Flow). Built programmatically and driven entirely by
## HeroDatabase, so the roster shown is whatever .tres files exist -- no
## hardcoded hero list.
##
## Covers: hero grid with portraits, selected-hero detail panel, per-pick
## countdown timer with auto-lock, lock-in, a "Suggest" that biases toward
## filling a missing class, and a live team-composition display.

signal hero_locked(team: int, hero: HeroDefinition)
signal draft_timed_out(team: int)

const CLASS_NAMES: Dictionary = {
	HeroDefinition.HeroClass.DAMAGE: "Damage",
	HeroDefinition.HeroClass.TANK: "Tank",
	HeroDefinition.HeroClass.SUPPORT: "Support",
	HeroDefinition.HeroClass.ENGINEER: "Engineer",
}
const ATTACK_NAMES: Dictionary = {
	HeroDefinition.AttackType.MELEE: "Melee",
	HeroDefinition.AttackType.RANGED: "Ranged",
	HeroDefinition.AttackType.MAGIC: "Magic",
}
const ROLE_NAMES: Dictionary = {
	HeroDefinition.RoleTag.ENGAGE: "Engage",
	HeroDefinition.RoleTag.PEEL: "Peel",
	HeroDefinition.RoleTag.POKE: "Poke",
	HeroDefinition.RoleTag.SPLIT_PUSH: "Split-push",
	HeroDefinition.RoleTag.OBJECTIVE: "Objective",
}

@export var team: int = MatchState.Team.TEAM_A
@export var draft_seconds: float = 30.0
## When true the timer runs and auto-locks at 0. Tests set this false.
@export var timer_enabled: bool = true

var _time_left: float = 0.0
var _selected_hero: HeroDefinition = null
var _locked: bool = false

var _hero_grid: GridContainer
var _detail_portrait: TextureRect
var _detail_label: RichTextLabel
var _timer_label: Label
var _status_label: Label
var _team_a_label: RichTextLabel
var _team_b_label: RichTextLabel
var _lock_button: Button
var _start_button: Button

func _ready() -> void:
	_time_left = draft_seconds
	_build_ui()
	_populate_hero_grid()
	_update_team_display()
	_refresh_timer_label()
	# Surface the roster-load state directly -- an empty grid is always a
	# HeroDatabase problem, never a UI one.
	if _status_label != null:
		_status_label.text = "%d heroes available -- pick one, or hit START MATCH" % HeroDatabase.count()

func _process(delta: float) -> void:
	if not timer_enabled or _locked:
		return
	_time_left = max(0.0, _time_left - delta)
	_refresh_timer_label()
	if _time_left <= 0.0:
		if _selected_hero == null:
			select_hero(_suggest_hero())
		lock_in()
		draft_timed_out.emit(team)

# --------------------------------------------------------------------------
# Public API (also what the tests drive)
# --------------------------------------------------------------------------

func get_hero_button_count() -> int:
	return _hero_grid.get_child_count() if _hero_grid != null else 0

func get_selected_hero() -> HeroDefinition:
	return _selected_hero

func is_locked() -> bool:
	return _locked

func get_time_left() -> float:
	return _time_left

func select_hero(hero: HeroDefinition) -> void:
	if hero == null or _locked:
		return
	AudioDirector.play_ui()
	_selected_hero = hero
	_show_detail(hero)
	if _lock_button != null:
		_lock_button.disabled = false

func lock_in() -> bool:
	if _locked or _selected_hero == null:
		return false
	_locked = true
	var picks: Array = _team_picks()
	if not picks.has(_selected_hero.hero_id):
		picks.append(_selected_hero.hero_id)
	if _lock_button != null:
		_lock_button.disabled = true
	if _start_button != null:
		_start_button.disabled = true
	_status_label.text = "LOCKED IN: %s" % _selected_hero.display_name
	_update_team_display()
	hero_locked.emit(team, _selected_hero)
	return true

## Skips the countdown entirely: locks in immediately, auto-picking a
## suggested hero when nothing is selected. Bound to the START MATCH button
## and also safe to call from tests.
func start_match() -> void:
	if _locked:
		return
	if _selected_hero == null:
		select_hero(_suggest_hero())
	lock_in()

func random_hero() -> HeroDefinition:
	var all: Array[HeroDefinition] = HeroDatabase.get_all_heroes()
	if all.is_empty():
		return null
	return all[randi() % all.size()]

## Picks a hero whose class is not yet represented on this team, so a draft
## of randoms still ends up with a sane team composition. Falls back to a
## random hero once every class is covered.
func suggest_hero() -> HeroDefinition:
	return _suggest_hero()

# --------------------------------------------------------------------------
# Internals
# --------------------------------------------------------------------------

func _suggest_hero() -> HeroDefinition:
	var covered: Dictionary = {}
	for hero_id in _team_picks():
		var hero: HeroDefinition = HeroDatabase.get_hero(hero_id)
		if hero != null:
			covered[hero.hero_class] = true
	for hero in HeroDatabase.get_all_heroes():
		if not covered.has(hero.hero_class):
			return hero
	return random_hero()

func _team_picks() -> Array:
	return MatchState.team_a_picks if team == MatchState.Team.TEAM_A else MatchState.team_b_picks

func _refresh_timer_label() -> void:
	if _timer_label != null:
		_timer_label.text = "%d" % int(ceil(_time_left))

func _populate_hero_grid() -> void:
	for child in _hero_grid.get_children():
		_hero_grid.remove_child(child)
		child.queue_free()
	for hero in HeroDatabase.get_all_heroes():
		var button := Button.new()
		button.text = hero.display_name
		button.custom_minimum_size = Vector2(150, 54)
		button.tooltip_text = "%s  /  %s" % [
			CLASS_NAMES.get(hero.hero_class, "?"),
			ATTACK_NAMES.get(hero.attack_type, "?"),
		]
		button.pressed.connect(select_hero.bind(hero))
		_hero_grid.add_child(button)

func _show_detail(hero: HeroDefinition) -> void:
	if _detail_portrait != null:
		_detail_portrait.texture = hero.portrait
	if _detail_label == null:
		return
	var lines: Array[String] = []
	lines.append("[b][font_size=24]%s[/font_size][/b]" % hero.display_name)
	lines.append("%s  /  %s  /  %s" % [
		CLASS_NAMES.get(hero.hero_class, "?"),
		ATTACK_NAMES.get(hero.attack_type, "?"),
		ROLE_NAMES.get(hero.role_tag, "?"),
	])
	lines.append("")
	lines.append("[b]Base Stats[/b]")
	lines.append("  HP %d    Move %d    Dash %d" % [
		int(hero.base_max_hp), int(hero.base_move_speed), int(hero.base_dash_speed)
	])
	lines.append("  Attack %d    Armor %d" % [
		int(hero.base_attack_damage), int(hero.base_armor)
	])
	lines.append("")
	lines.append("[b]Kit[/b]")
	for ability in [hero.skill_1, hero.skill_2, hero.skill_3, hero.ultimate]:
		if ability != null:
			var label: String = "  [color=#9fd0ff]%s[/color] — %s" % [
				ability.display_name, ability.description.split(".")[0]
			]
			lines.append(label)
	if hero.synergy_note != "":
		lines.append("")
		lines.append("[i]%s[/i]" % hero.synergy_note)
	if hero.lore_hook != "":
		lines.append("")
		lines.append("[color=#c0c0c0]%s[/color]" % hero.lore_hook)
	_detail_label.text = "\n".join(lines)

func _update_team_display() -> void:
	_team_a_label.text = _format_team("TEAM A", MatchState.team_a_picks)
	_team_b_label.text = _format_team("TEAM B", MatchState.team_b_picks)

func _format_team(title: String, picks: Array) -> String:
	var lines: Array[String] = ["[b]%s[/b]" % title]
	if picks.is_empty():
		lines.append("  (empty)")
	for hero_id in picks:
		var hero: HeroDefinition = HeroDatabase.get_hero(hero_id)
		if hero != null:
			lines.append("  %s (%s)" % [hero.display_name, CLASS_NAMES.get(hero.hero_class, "?")])
	return "\n".join(lines)

# --------------------------------------------------------------------------
# UI construction
# --------------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.11, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "SELECT YOUR HERO"
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_timer_label = Label.new()
	_timer_label.add_theme_font_size_override("font_size", 34)
	_timer_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	header.add_child(_timer_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	root.add_child(body)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var grid_scroll := ScrollContainer.new()
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(grid_scroll)
	_hero_grid = GridContainer.new()
	_hero_grid.columns = 3
	_hero_grid.add_theme_constant_override("h_separation", 10)
	_hero_grid.add_theme_constant_override("v_separation", 10)
	grid_scroll.add_child(_hero_grid)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	left.add_child(buttons)
	var random_button := Button.new()
	random_button.text = "Random"
	random_button.custom_minimum_size = Vector2(140, 48)
	random_button.pressed.connect(func() -> void: select_hero(random_hero()))
	buttons.add_child(random_button)
	var suggest_button := Button.new()
	suggest_button.text = "Suggest"
	suggest_button.custom_minimum_size = Vector2(140, 48)
	suggest_button.pressed.connect(func() -> void: select_hero(_suggest_hero()))
	buttons.add_child(suggest_button)
	_lock_button = Button.new()
	_lock_button.text = "LOCK IN"
	_lock_button.custom_minimum_size = Vector2(180, 48)
	_lock_button.disabled = true
	_lock_button.pressed.connect(lock_in)
	buttons.add_child(_lock_button)
	_start_button = Button.new()
	_start_button.text = "START MATCH"
	_start_button.custom_minimum_size = Vector2(200, 48)
	_start_button.pressed.connect(start_match)
	buttons.add_child(_start_button)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(460, 0)
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	_detail_portrait = TextureRect.new()
	_detail_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_portrait.custom_minimum_size = Vector2(0, 360)
	right.add_child(_detail_portrait)
	_detail_label = RichTextLabel.new()
	_detail_label.bbcode_enabled = true
	_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_detail_label)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 24)
	root.add_child(footer)
	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_status_label)
	_team_a_label = RichTextLabel.new()
	_team_a_label.bbcode_enabled = true
	_team_a_label.custom_minimum_size = Vector2(300, 0)
	footer.add_child(_team_a_label)
	_team_b_label = RichTextLabel.new()
	_team_b_label.bbcode_enabled = true
	_team_b_label.custom_minimum_size = Vector2(300, 0)
	footer.add_child(_team_b_label)

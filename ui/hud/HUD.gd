class_name HUD
extends Control
## In-match HUD: player HP, gold, and the four skill slots with live cooldown
## readout. Binds to a CharacterController via bind_hero() and reads the
## player's gold from MatchEconomy. Purely a view -- it mutates nothing.

@export var player_id: int = 0

const SKILL_KEYS: Array[String] = ["Q", "E", "R", "F"]

var _hero: CharacterController = null
var _hp_bar: ProgressBar
var _hp_label: Label
var _gold_label: Label
var _skill_box: HBoxContainer
var _skill_labels: Array[Label] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()

func bind_hero(hero: CharacterController) -> void:
	_hero = hero
	_rebuild_skill_slots()

func _process(_delta: float) -> void:
	_refresh()

# --------------------------------------------------------------------------
# Internals
# --------------------------------------------------------------------------

func _hero_abilities() -> Array:
	if _hero == null or _hero.hero_definition == null:
		return []
	var h: HeroDefinition = _hero.hero_definition
	return [h.skill_1, h.skill_2, h.skill_3, h.ultimate]

func _refresh() -> void:
	if _gold_label != null:
		_gold_label.text = "Gold: %d" % MatchEconomy.get_gold(player_id)
	if _hero == null or not is_instance_valid(_hero):
		return
	if _hp_bar != null:
		_hp_bar.max_value = maxf(1.0, _hero.max_hp)
		_hp_bar.value = _hero.current_hp
	if _hp_label != null:
		_hp_label.text = "%d / %d" % [int(_hero.current_hp), int(_hero.max_hp)]
	var abilities: Array = _hero_abilities()
	for i in range(min(abilities.size(), _skill_labels.size())):
		var ability: AbilityDefinition = abilities[i]
		var label: Label = _skill_labels[i]
		if ability == null:
			label.text = "[%s] -" % SKILL_KEYS[i]
			continue
		var remaining: float = _hero.get_cooldown_remaining(ability)
		if remaining > 0.0:
			label.text = "[%s] %s  %.1fs" % [SKILL_KEYS[i], ability.display_name, remaining]
			label.modulate = Color(0.6, 0.6, 0.6)
		else:
			label.text = "[%s] %s  READY" % [SKILL_KEYS[i], ability.display_name]
			label.modulate = Color(1, 1, 1)

func _rebuild_skill_slots() -> void:
	for child in _skill_box.get_children():
		_skill_box.remove_child(child)
		child.queue_free()
	_skill_labels.clear()
	var abilities: Array = _hero_abilities()
	for i in range(abilities.size()):
		var label := Label.new()
		label.custom_minimum_size = Vector2(170, 34)
		_skill_box.add_child(label)
		_skill_labels.append(label)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var root := VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(root)

	# Top row: HP (left) + gold (right).
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)

	var hp_box := VBoxContainer.new()
	hp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_box.custom_minimum_size = Vector2(360, 0)
	top.add_child(hp_box)
	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 18)
	hp_box.add_child(_hp_label)
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(360, 22)
	_hp_bar.show_percentage = false
	hp_box.add_child(_hp_bar)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 24)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	top.add_child(_gold_label)

	# Push the skill bar to the bottom.
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom_spacer)

	var skill_row := CenterContainer.new()
	skill_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(skill_row)
	_skill_box = HBoxContainer.new()
	_skill_box.add_theme_constant_override("separation", 12)
	_skill_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_row.add_child(_skill_box)

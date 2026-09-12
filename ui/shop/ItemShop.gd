class_name ItemShop
extends Control
## Data-driven Item Shop UI (docs/ARCHITECTURE.md, Item Shop & Economy).
##
## Built entirely in code rather than authored as a deep .tscn tree, so it
## can never drift from the ItemDefinition schema: adding an item .tres to
## res://items/ makes it appear here automatically. Categories are for UI
## organization ONLY -- any class can buy any item, and there is no
## hero_class check anywhere in this file by design.

signal purchase_succeeded(player_id: int, item: ItemDefinition)
signal purchase_failed(player_id: int, item: ItemDefinition, reason: String)

const CATEGORY_ORDER: Array[ItemDefinition.Category] = [
	ItemDefinition.Category.DAMAGE,
	ItemDefinition.Category.TANK,
	ItemDefinition.Category.UTILITY,
	ItemDefinition.Category.MAGIC,
]
const CATEGORY_NAMES: Dictionary = {
	ItemDefinition.Category.DAMAGE: "Damage",
	ItemDefinition.Category.TANK: "Tank",
	ItemDefinition.Category.UTILITY: "Utility",
	ItemDefinition.Category.MAGIC: "Magic",
}

@export var player_id: int = 0

var _selected_category: ItemDefinition.Category = ItemDefinition.Category.DAMAGE
var _item_list: VBoxContainer
var _detail_label: RichTextLabel
var _gold_label: Label
var _category_buttons: Dictionary = {}

func _ready() -> void:
	_build_ui()
	MatchEconomy.gold_changed.connect(_on_gold_changed)
	PlayerInventory.item_added.connect(_on_item_added)
	_refresh()

# --------------------------------------------------------------------------
# Public API (also what the tests drive)
# --------------------------------------------------------------------------

func select_category(category: ItemDefinition.Category) -> void:
	_selected_category = category
	_refresh()

func get_visible_item_count() -> int:
	return _item_list.get_child_count() if _item_list != null else 0

## Attempts to buy `item` for `player_id`. Returns true on success. This is
## the single purchase path -- the button handler just calls it.
func try_purchase(item: ItemDefinition) -> bool:
	if item == null:
		return false
	if not MatchEconomy.spend_gold(player_id, item.gold_cost):
		var reason: String = "Not enough gold (need %d, have %d)" % [
			item.gold_cost, MatchEconomy.get_gold(player_id)
		]
		purchase_failed.emit(player_id, item, reason)
		_show_detail(item, reason)
		return false
	PlayerInventory.add_item(player_id, item)
	purchase_succeeded.emit(player_id, item)
	_show_detail(item, "Purchased!")
	_refresh()
	return true

# --------------------------------------------------------------------------
# UI construction
# --------------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.10, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "ITEM SHOP"
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 24)
	header.add_child(_gold_label)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)
	for category in CATEGORY_ORDER:
		var button := Button.new()
		button.text = CATEGORY_NAMES[category]
		button.custom_minimum_size = Vector2(150, 44)
		button.pressed.connect(select_category.bind(category))
		tabs.add_child(button)
		_category_buttons[category] = button

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	root.add_child(body)

	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(list_scroll)
	_item_list = VBoxContainer.new()
	_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_list.add_theme_constant_override("separation", 6)
	list_scroll.add_child(_item_list)

	_detail_label = RichTextLabel.new()
	_detail_label.bbcode_enabled = true
	_detail_label.custom_minimum_size = Vector2(420, 0)
	_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_detail_label)

# --------------------------------------------------------------------------
# Refresh / events
# --------------------------------------------------------------------------

func _refresh() -> void:
	if _gold_label != null:
		_gold_label.text = "Gold: %d" % MatchEconomy.get_gold(player_id)
	if _item_list == null:
		return
	for child in _item_list.get_children():
		# Detach immediately, not just queue_free(): a queued child still
		# counts in get_child_count() until end of frame, which would make
		# get_visible_item_count() lie right after a category switch.
		_item_list.remove_child(child)
		child.queue_free()
	for item in ItemDatabase.get_items_by_category(_selected_category):
		_item_list.add_child(_make_item_row(item))
	for category in _category_buttons:
		var button: Button = _category_buttons[category]
		button.disabled = (category == _selected_category)

func _make_item_row(item: ItemDefinition) -> Button:
	var button := Button.new()
	var owned: bool = PlayerInventory.owns(player_id, item.item_id)
	var suffix: String = "   [OWNED]" if owned else ""
	button.text = "%s    %dg%s" % [item.display_name, item.gold_cost, suffix]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 46)
	button.tooltip_text = item.passive_description
	button.pressed.connect(try_purchase.bind(item))
	button.mouse_entered.connect(_show_detail.bind(item, ""))
	return button

func _show_detail(item: ItemDefinition, extra: String) -> void:
	if _detail_label == null or item == null:
		return
	var lines: Array[String] = []
	lines.append("[b][font_size=22]%s[/font_size][/b]" % item.display_name)
	lines.append("[i]%s[/i]" % item.description)
	lines.append("Cost: [color=#ffd479]%dg[/color]" % item.gold_cost)
	lines.append("")
	var stats: Array[String] = []
	if item.bonus_max_hp != 0.0:
		stats.append("+%d Max HP" % int(item.bonus_max_hp))
	if item.bonus_move_speed != 0.0:
		stats.append("+%d Move Speed" % int(item.bonus_move_speed))
	if item.bonus_dash_speed != 0.0:
		stats.append("+%d Dash Speed" % int(item.bonus_dash_speed))
	if item.bonus_attack_damage != 0.0:
		stats.append("+%d Attack Damage" % int(item.bonus_attack_damage))
	if item.bonus_ability_power != 0.0:
		stats.append("+%d Ability Power" % int(item.bonus_ability_power))
	if item.bonus_armor != 0.0:
		stats.append("+%d Armor" % int(item.bonus_armor))
	if item.bonus_cooldown_reduction != 0.0:
		stats.append("+%d%% Cooldown Reduction" % int(item.bonus_cooldown_reduction * 100.0))
	if stats.size() > 0:
		lines.append("[b]Stats[/b]")
		for stat in stats:
			lines.append("  " + stat)
	if item.passive_description != "":
		lines.append("")
		lines.append("[b]Passive[/b]")
		lines.append("  " + item.passive_description)
	if extra != "":
		lines.append("")
		lines.append("[color=#ffd479]%s[/color]" % extra)
	_detail_label.text = "\n".join(lines)

func _on_gold_changed(changed_player_id: int, _amount: int) -> void:
	if changed_player_id == player_id:
		_refresh()

func _on_item_added(added_player_id: int, _item: ItemDefinition) -> void:
	if added_player_id == player_id:
		_refresh()

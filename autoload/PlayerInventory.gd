extends Node
## Autoload singleton: per-player purchased-item inventory + aggregate stat
## math (see docs/ARCHITECTURE.md, Item Shop & Economy). The shop buys
## through MatchEconomy (gold) and registers the item here; anything that
## needs a player's effective stats should read get_total_stats() so item
## bonuses are applied in exactly one place.
##
## Cross-class purchasing is intentional: there is NO hero_class gating
## anywhere in this file or in ItemDefinition -- any player can own any item.

signal item_added(player_id: int, item: ItemDefinition)
signal item_removed(player_id: int, item: ItemDefinition)

var _items: Dictionary = {} # player_id: int -> Array[ItemDefinition]

func clear_all() -> void:
	_items.clear()

func get_items(player_id: int) -> Array[ItemDefinition]:
	# Must build a typed array explicitly: the stored value is an untyped
	# Array, and returning that directly fails the Array[ItemDefinition]
	# return type at runtime.
	var result: Array[ItemDefinition] = []
	for item in _items.get(player_id, []):
		if item is ItemDefinition:
			result.append(item)
	return result

func owns(player_id: int, item_id: StringName) -> bool:
	for item in get_items(player_id):
		if item.item_id == item_id:
			return true
	return false

func add_item(player_id: int, item: ItemDefinition) -> void:
	if item == null:
		return
	if not _items.has(player_id):
		_items[player_id] = []
	_items[player_id].append(item)
	item_added.emit(player_id, item)

func remove_item(player_id: int, item: ItemDefinition) -> void:
	if item == null or not _items.has(player_id):
		return
	var arr: Array = _items[player_id]
	var idx: int = arr.find(item)
	if idx >= 0:
		arr.remove_at(idx)
		item_removed.emit(player_id, item)

## Summed bonuses across every owned item. Keys are the ItemDefinition
## bonus_* field names with the "bonus_" prefix stripped.
func get_total_stats(player_id: int) -> Dictionary:
	var totals: Dictionary = {
		"max_hp": 0.0,
		"move_speed": 0.0,
		"dash_speed": 0.0,
		"attack_damage": 0.0,
		"ability_power": 0.0,
		"armor": 0.0,
		"cooldown_reduction": 0.0,
	}
	for item in get_items(player_id):
		totals["max_hp"] += item.bonus_max_hp
		totals["move_speed"] += item.bonus_move_speed
		totals["dash_speed"] += item.bonus_dash_speed
		totals["attack_damage"] += item.bonus_attack_damage
		totals["ability_power"] += item.bonus_ability_power
		totals["armor"] += item.bonus_armor
		totals["cooldown_reduction"] += item.bonus_cooldown_reduction
	return totals

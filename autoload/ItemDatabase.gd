extends Node
## Autoload singleton: loads every ItemDefinition .tres under res://items/.
## The shop UI reads from get_items_by_category() -- categories are for UI
## organization only, every item is purchasable by every class (see
## docs/ARCHITECTURE.md, Item Shop & Economy).

const ITEMS_DIR: String = "res://items/"

var _items: Dictionary = {} # StringName -> ItemDefinition

func _ready() -> void:
	_load_all_items()

func _load_all_items() -> void:
	_items.clear()
	var dir := DirAccess.open(ITEMS_DIR)
	if dir == null:
		push_warning("ItemDatabase: %s not found yet (no items authored)." % ITEMS_DIR)
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".tres"):
			var res: Resource = load(ITEMS_DIR + entry)
			if res is ItemDefinition:
				_items[(res as ItemDefinition).item_id] = res
		entry = dir.get_next()
	dir.list_dir_end()

func reload() -> void:
	_load_all_items()

func get_item(item_id: StringName) -> ItemDefinition:
	return _items.get(item_id)

func get_all_items() -> Array[ItemDefinition]:
	var out: Array[ItemDefinition] = []
	for i in _items.values():
		out.append(i)
	return out

func get_items_by_category(category: ItemDefinition.Category) -> Array[ItemDefinition]:
	return get_all_items().filter(
		func(i: ItemDefinition) -> bool: return i.category == category
	)

func count() -> int:
	return _items.size()

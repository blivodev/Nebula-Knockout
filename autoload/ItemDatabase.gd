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
	for entry in _list_resource_dir(ITEMS_DIR):
		if not entry.ends_with(".tres"):
			continue
		var res: Resource = load(ITEMS_DIR + entry)
		if res is ItemDefinition:
			_items[(res as ItemDefinition).item_id] = res
	if _items.is_empty():
		push_warning("ItemDatabase: no ItemDefinition .tres resources loaded from %s." % ITEMS_DIR)

## Export-safe resource listing. DirAccess on res:// inside an exported PCK
## only returns *.gd / *.import stubs (text resources are remapped to binary),
## which silently emptied the shop in exported builds. See HeroDatabase.
func _list_resource_dir(path: String) -> PackedStringArray:
	if ResourceLoader.has_method("list_directory"):
		return ResourceLoader.list_directory(path)
	var out := PackedStringArray()
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".tres"):
			out.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	return out

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

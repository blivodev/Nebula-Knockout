extends Node
## Autoload singleton: loads every HeroDefinition .tres under res://heroes/
## at startup and exposes lookup by id/class. Adding hero #31 means
## dropping a new .tres in res://heroes/ -- no code changes required
## (see docs/ARCHITECTURE.md).

const HEROES_DIR: String = "res://heroes/"

var _heroes: Dictionary = {} # StringName -> HeroDefinition

func _ready() -> void:
	_load_all_heroes()

func _load_all_heroes() -> void:
	_heroes.clear()
	for entry in _list_resource_dir(HEROES_DIR):
		if not entry.ends_with(".tres"):
			continue
		var res: Resource = load(HEROES_DIR + entry)
		if res is HeroDefinition:
			_heroes[(res as HeroDefinition).hero_id] = res
	if _heroes.is_empty():
		push_warning("HeroDatabase: no HeroDefinition .tres resources loaded from %s." % HEROES_DIR)

## Export-safe resource listing. DirAccess on res:// inside an exported PCK
## only returns *.gd / *.import stubs (text resources are remapped to binary
## and become invisible to directory scans), which silently emptied the
## roster in exported builds. ResourceLoader.list_directory() reports the
## editor-visible resource names in BOTH editor and exported builds.
func _list_resource_dir(path: String) -> PackedStringArray:
	if ResourceLoader.has_method("list_directory"):
		return ResourceLoader.list_directory(path)
	# Editor / older-engine fallback: plain filesystem scan.
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
	_load_all_heroes()

func get_hero(hero_id: StringName) -> HeroDefinition:
	return _heroes.get(hero_id)

func get_all_heroes() -> Array[HeroDefinition]:
	var out: Array[HeroDefinition] = []
	for h in _heroes.values():
		out.append(h)
	return out

func get_heroes_by_class(hero_class: HeroDefinition.HeroClass) -> Array[HeroDefinition]:
	return get_all_heroes().filter(
		func(h: HeroDefinition) -> bool: return h.hero_class == hero_class
	)

func count() -> int:
	return _heroes.size()

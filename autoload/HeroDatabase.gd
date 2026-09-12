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
	var dir := DirAccess.open(HEROES_DIR)
	if dir == null:
		push_warning("HeroDatabase: %s not found yet (no heroes authored)." % HEROES_DIR)
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".tres"):
			var res: Resource = load(HEROES_DIR + entry)
			if res is HeroDefinition:
				_heroes[(res as HeroDefinition).hero_id] = res
		entry = dir.get_next()
	dir.list_dir_end()

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

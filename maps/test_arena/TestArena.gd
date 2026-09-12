extends Node2D
## Proof-of-loop arena: one lane, two perfectly mirrored bases, and
## synchronized minion waves on a timer. This is the target of
## tests/unit/test_map_symmetry.gd, and proves the core MOBA loop
## end-to-end (mirrored structures, NavigationAgent2D lane pathing,
## minion-vs-minion/tower aggro, gold economy) before any hero content
## exists. See docs/ARCHITECTURE.md, Execution step 2.

const LANE_HALF_LENGTH: float = 800.0
const LANE_HALF_WIDTH: float = 200.0
const NAV_PADDING: float = 100.0
const WAVE_INTERVAL_SEC: float = 20.0
const MINIONS_PER_WAVE: int = 3
const MINION_SPACING: float = 40.0

const MainBuildingScene: PackedScene = preload("res://entities/main_building/MainBuilding.tscn")
const LaneMinionScene: PackedScene = preload("res://entities/lane_minion/LaneMinion.tscn")
const HudScene: PackedScene = preload("res://ui/hud/HUD.tscn")
const ItemShopScene: PackedScene = preload("res://ui/shop/ItemShop.tscn")

## Set false in tests / headless loop checks that don't want a local player.
@export var spawn_player_hero: bool = true
## Which hero the local player controls. The match flow sets this from the
## draft result; it defaults to Kael for standalone arena runs.
@export var player_hero_id: StringName = &"kael"

@onready var nav_region: NavigationRegion2D = $NavigationRegion2D
@onready var minions_root: Node2D = $Minions
@onready var camera: Camera2D = $Camera2D

var _wave_timer: float = 0.0
var _base_a: MainBuilding
var _base_b: MainBuilding
var _player_hero: CharacterController
var _hud: HUD
var _shop: ItemShop

func _ready() -> void:
	_build_navigation()
	MatchEconomy.register_player(0)
	MatchEconomy.register_player(1)
	_spawn_bases()
	if spawn_player_hero:
		_spawn_player_hero()
		_setup_ui()
	MatchState.set_phase(MatchState.Phase.IN_PROGRESS)
	# First wave immediately so the loop is visible without waiting.
	_spawn_wave()

## Wires the in-match HUD to the player hero and adds the shop (hidden until
## toggled with B).
func _setup_ui() -> void:
	_hud = HudScene.instantiate() as HUD
	_hud.player_id = 0
	add_child(_hud)
	_hud.bind_hero(_player_hero)

	_shop = ItemShopScene.instantiate() as ItemShop
	_shop.player_id = 0
	_shop.visible = false
	add_child(_shop)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_B and _shop != null:
			_shop.visible = not _shop.visible

func _spawn_player_hero() -> void:
	var hero_def: HeroDefinition = HeroDatabase.get_hero(player_hero_id)
	if hero_def == null or hero_def.scene_path == "":
		push_warning("TestArena: no playable scene for hero '%s'; skipping spawn" % player_hero_id)
		return
	var scene: PackedScene = load(hero_def.scene_path)
	if scene == null:
		push_warning("TestArena: failed to load hero scene %s" % hero_def.scene_path)
		return
	_player_hero = scene.instantiate() as CharacterController
	_player_hero.team = MatchState.Team.TEAM_A
	_player_hero.player_id = 0
	_player_hero.is_player_controlled = true
	_player_hero.position = _base_a.position + Vector2(140.0, 0.0)
	add_child(_player_hero)

func _build_navigation() -> void:
	var nav_poly := NavigationPolygon.new()
	var hl: float = LANE_HALF_LENGTH + NAV_PADDING
	var hw: float = LANE_HALF_WIDTH
	nav_poly.vertices = PackedVector2Array([
		Vector2(-hl, -hw), Vector2(hl, -hw), Vector2(hl, hw), Vector2(-hl, hw),
	])
	nav_poly.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	nav_region.navigation_polygon = nav_poly

func _spawn_bases() -> void:
	_base_a = MainBuildingScene.instantiate()
	_base_a.team = MatchState.Team.TEAM_A
	_base_a.position = Vector2(-LANE_HALF_LENGTH, 0.0)
	add_child(_base_a)

	_base_b = MainBuildingScene.instantiate()
	_base_b.team = MatchState.Team.TEAM_B
	_base_b.position = MatchState.mirror_position(_base_a.position)
	add_child(_base_b)

func _process(delta: float) -> void:
	if MatchState.phase != MatchState.Phase.IN_PROGRESS:
		return
	_wave_timer += delta
	if _wave_timer >= WAVE_INTERVAL_SEC:
		_wave_timer = 0.0
		_spawn_wave()
	_follow_player(delta)

func _follow_player(delta: float) -> void:
	if _player_hero == null or not is_instance_valid(_player_hero):
		return
	camera.global_position = camera.global_position.lerp(
		_player_hero.global_position, clampf(delta * 6.0, 0.0, 1.0)
	)

func _spawn_wave() -> void:
	_spawn_lane_wave(MatchState.Team.TEAM_A, _base_a.position, _base_b.position)
	_spawn_lane_wave(MatchState.Team.TEAM_B, _base_b.position, _base_a.position)

func _spawn_lane_wave(team: MatchState.Team, from: Vector2, to: Vector2) -> void:
	for i in range(MINIONS_PER_WAVE):
		var minion: LaneMinion = LaneMinionScene.instantiate()
		minion.team = team
		minion.waypoints = [to]
		var offset: float = (i - (MINIONS_PER_WAVE - 1) * 0.5) * MINION_SPACING
		minion.position = from + Vector2(0.0, offset)
		minions_root.add_child(minion)

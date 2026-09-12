extends GutTest
## Verifies TestArena's two bases are exact mirrors around the map center
## (docs/ARCHITECTURE.md, Map Balance). Extend this once towers/jungle
## camps/the boss exist -- every one of them must pass an equivalent check.

const TestArenaScene: PackedScene = preload("res://maps/test_arena/TestArena.tscn")

var _arena: Node2D

func before_each() -> void:
	MatchState.set_phase(MatchState.Phase.DRAFT) # reset between tests
	_arena = TestArenaScene.instantiate()
	add_child_autofree(_arena)
	await wait_physics_frames(2)

func test_bases_are_mirrored_positions() -> void:
	var pos_a: Vector2 = _arena._base_a.position
	var pos_b: Vector2 = _arena._base_b.position
	var expected_b: Vector2 = MatchState.mirror_position(pos_a)
	assert_almost_eq(pos_b.x, expected_b.x, 0.01, "Base B.x should mirror Base A.x")
	assert_almost_eq(pos_b.y, expected_b.y, 0.01, "Base B.y should equal Base A.y")

func test_bases_have_identical_hitbox_size() -> void:
	var bounds_a: Rect2 = _arena._base_a.get_world_bounds()
	var bounds_b: Rect2 = _arena._base_b.get_world_bounds()
	assert_almost_eq(bounds_a.size.x, bounds_b.size.x, 0.01, "Hitbox width must match both sides")
	assert_almost_eq(bounds_a.size.y, bounds_b.size.y, 0.01, "Hitbox height must match both sides")

func test_bases_have_identical_max_hp() -> void:
	assert_eq(_arena._base_a.max_hp, _arena._base_b.max_hp, "Both bases must have identical max HP")

func test_bases_are_on_opposite_teams() -> void:
	assert_ne(_arena._base_a.team, _arena._base_b.team, "Bases must belong to different teams")

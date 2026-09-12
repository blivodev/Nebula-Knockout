extends GutTest
## Exercises HeroRigImporter end-to-end using procedurally-generated
## placeholder textures (no real MCP-generated art exists yet), verifying
## the JSON schema parses, the Bone2D hierarchy resolves correctly
## regardless of listing order, and pivot-based offsets are computed
## correctly for a known texture size.

const SAMPLE_RIG_JSON: String = """
{
  "hero_id": "test_hero",
  "bones": [
    { "name": "upper_arm_r", "parent": "torso", "pivot": [0.1, 0.15], "z_index": 1, "texture": "arm.png" },
    { "name": "torso", "parent": "root", "pivot": [0.5, 0.2], "z_index": 0, "texture": "torso.png" },
    { "name": "forearm_r", "parent": "upper_arm_r", "pivot": [0.2, 0.5], "z_index": 2, "texture": "forearm.png" }
  ]
}
"""

func _make_placeholder_texture(_name: String) -> Texture2D:
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)

func test_parse_rig_json_returns_expected_structure() -> void:
	var data: Dictionary = HeroRigImporter.parse_rig_json(SAMPLE_RIG_JSON)
	assert_eq(data.get("hero_id"), "test_hero")
	assert_eq((data.get("bones") as Array).size(), 3)

func test_parse_rig_json_rejects_malformed_input() -> void:
	var data: Dictionary = HeroRigImporter.parse_rig_json("not json at all")
	assert_true(data.is_empty())
	# Malformed input is EXPECTED to log an engine parse error + our own
	# push_error -- acknowledge both so GUT doesn't treat them as failures.
	for err in get_errors():
		err.handled = true

func test_build_rig_resolves_hierarchy_regardless_of_listing_order() -> void:
	var data: Dictionary = HeroRigImporter.parse_rig_json(SAMPLE_RIG_JSON)
	# Deliberately NOT added to the live scene tree: Bone2D/Skeleton2D only
	# need to be in-tree for pose evaluation, not for structural queries
	# like get_node(), and GUT's add_child_autofree() interacting with a
	# freshly-built (never-baked-rest) Bone2D hierarchy trips an unrelated
	# engine transform-inversion warning during teardown. Free it directly
	# once the assertions are done instead.
	var skeleton: Skeleton2D = HeroRigImporter.build_rig(data, "", _make_placeholder_texture)

	var torso: Node = skeleton.get_node_or_null("torso")
	assert_not_null(torso, "torso should be a direct child of the skeleton root")

	var upper_arm: Node = torso.get_node_or_null("upper_arm_r") if torso != null else null
	assert_not_null(upper_arm, "upper_arm_r should be parented under torso")

	var forearm: Node = upper_arm.get_node_or_null("forearm_r") if upper_arm != null else null
	assert_not_null(forearm, "forearm_r should be parented under upper_arm_r")

	skeleton.free()

func test_build_rig_computes_pivot_offset_from_texture_size() -> void:
	var data: Dictionary = HeroRigImporter.parse_rig_json(SAMPLE_RIG_JSON)
	var skeleton: Skeleton2D = HeroRigImporter.build_rig(data, "", _make_placeholder_texture)

	var torso: Bone2D = skeleton.get_node("torso")
	var visual: Sprite2D = torso.get_node("Visual")
	# 64x32 placeholder texture, pivot [0.5, 0.2] -> offset (-32, -6.4)
	assert_almost_eq(visual.offset.x, -32.0, 0.01)
	assert_almost_eq(visual.offset.y, -6.4, 0.01)

	skeleton.free()

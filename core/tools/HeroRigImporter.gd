@tool
class_name HeroRigImporter
extends RefCounted
## Converts a rigging-metadata JSON (schema defined in
## docs/deepseek_prompt.md, Section 1) into a Skeleton2D + Bone2D hierarchy
## with one textured cutout sprite per bone. This is for hero-select/menu
## showcase puppeteering ONLY (docs/ARCHITECTURE.md, Section 3) -- in-match
## gameplay animation uses baked AnimatedSprite2D/SpriteFrames flipbooks
## instead, generated separately from the same rig.
##
## Implementation note: this builds a RIGID cutout rig (each bone parents
## exactly one sprite, offset by its pivot) rather than a soft-body
## Polygon2D mesh skinned across multiple bones with per-vertex weights.
## That's the right tool for jointed rigid limb pieces (torso/arm/forearm/
## hand/etc.) and is far simpler to get right than true vertex skinning,
## which this cutout character style doesn't actually need.

## Expected rig JSON shape:
## {
##   "hero_id": "kael",
##   "bones": [
##     { "name": "torso", "parent": "root", "pivot": [0.5, 0.2],
##       "z_index": 0, "texture": "kael_torso.png" },
##     { "name": "upper_arm_r", "parent": "torso", "pivot": [0.1, 0.15],
##       "z_index": 1, "texture": "kael_upper_arm_r.png" }
##   ]
## }
static func parse_rig_json(json_text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(json_text)
	if parsed == null or not (parsed is Dictionary) or not parsed.has("bones"):
		push_error("HeroRigImporter: invalid rig JSON (expected a dict with a 'bones' array)")
		return {}
	return parsed

## Builds a Skeleton2D scene tree from parsed rig data.
## `texture_dir` is prefixed onto each bone's "texture" filename to load the
## real art. Pass `texture_loader` to override texture resolution entirely
## (used by tests to hand back procedurally-generated stand-in textures
## instead of touching the filesystem).
static func build_rig(
	rig_data: Dictionary,
	texture_dir: String = "",
	texture_loader: Callable = Callable()
) -> Skeleton2D:
	var skeleton := Skeleton2D.new()
	skeleton.name = "%s_Rig" % str(rig_data.get("hero_id", "hero"))

	var bone_nodes: Dictionary = {} # bone name (String) -> Bone2D
	var remaining: Array = (rig_data.get("bones", []) as Array).duplicate()

	# The schema doesn't guarantee parents are listed before their
	# children, so resolve in dependency order: keep sweeping the
	# remaining list and place whatever bone's parent already exists,
	# until nothing more can be placed.
	var safety_counter: int = remaining.size() * remaining.size() + 4
	while remaining.size() > 0 and safety_counter > 0:
		safety_counter -= 1
		var i: int = 0
		while i < remaining.size():
			var entry: Dictionary = remaining[i]
			var parent_name: String = str(entry.get("parent", "root"))
			var parent_node: Node = skeleton if parent_name == "root" else bone_nodes.get(parent_name)
			if parent_node == null:
				i += 1
				continue
			var bone := _build_bone_node(entry, texture_dir, texture_loader)
			parent_node.add_child(bone)
			bone_nodes[str(entry.get("name", ""))] = bone
			remaining.remove_at(i)

	if remaining.size() > 0:
		push_warning("HeroRigImporter: %d bone(s) had unresolvable parents and were skipped" % remaining.size())

	return skeleton

static func _build_bone_node(entry: Dictionary, texture_dir: String, texture_loader: Callable) -> Bone2D:
	var bone := Bone2D.new()
	bone.name = str(entry.get("name", "bone"))

	var sprite := Sprite2D.new()
	sprite.name = "Visual"
	sprite.z_index = int(entry.get("z_index", 0))
	sprite.centered = false

	var texture_name: String = str(entry.get("texture", ""))
	var texture: Texture2D = null
	if texture_loader.is_valid():
		texture = texture_loader.call(texture_name)
	elif texture_name != "" and texture_dir != "":
		var path: String = texture_dir.path_join(texture_name)
		if ResourceLoader.exists(path):
			texture = load(path)
		else:
			push_warning("HeroRigImporter: texture not found: %s" % path)

	if texture != null:
		sprite.texture = texture
		var pivot: Array = entry.get("pivot", [0.5, 0.5])
		var size: Vector2 = texture.get_size()
		# pivot is normalized [0,1] within the texture; offset shifts the
		# sprite so that point lands exactly on the Bone2D's own origin,
		# which is what makes rotation/scale pivot around the right joint.
		sprite.offset = -Vector2(float(pivot[0]) * size.x, float(pivot[1]) * size.y)

	bone.add_child(sprite)
	return bone

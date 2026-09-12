extends GutTest
## Verifies every hero scene instantiates cleanly, uses its MCP-generated
## art (docs/ART_STYLE.md), has the Hurtbox/Hitbox nodes CharacterController
## expects, and points at the matching HeroDefinition resource.

const HERO_SCENES: Dictionary = {
	&"kael": "res://entities/heroes/kael/Kael.tscn",
	&"bastion": "res://entities/heroes/bastion/Bastion.tscn",
	&"monk": "res://entities/heroes/monk/Monk.tscn",
	&"machinist": "res://entities/heroes/machinist/Machinist.tscn",
	&"pyra": "res://entities/heroes/pyra/Pyra.tscn",
	&"void": "res://entities/heroes/void/Void.tscn",
	&"flint": "res://entities/heroes/flint/Flint.tscn",
	&"vex": "res://entities/heroes/vex/Vex.tscn",
}

func test_every_hero_scene_loads_with_art_and_combat_nodes() -> void:
	for hero_id in HERO_SCENES:
		var path: String = HERO_SCENES[hero_id]
		var scene: PackedScene = load(path)
		assert_not_null(scene, "failed to load %s" % path)
		if scene == null:
			continue
		var instance: Node2D = scene.instantiate()
		add_child_autofree(instance)

		var visual: Node = instance.get_node_or_null("Visual")
		assert_not_null(visual, "%s has no Visual node" % hero_id)
		assert_true(visual is Sprite2D, "%s Visual should be a Sprite2D" % hero_id)
		if visual is Sprite2D:
			assert_not_null((visual as Sprite2D).texture, "%s Visual has no texture" % hero_id)
		assert_not_null(instance.get_node_or_null("Hurtbox"), "%s missing Hurtbox" % hero_id)
		assert_not_null(instance.get_node_or_null("Hitbox"), "%s missing Hitbox" % hero_id)

func test_every_hero_scene_points_at_the_matching_definition() -> void:
	for hero_id in HERO_SCENES:
		var scene: PackedScene = load(HERO_SCENES[hero_id])
		var instance: Node2D = scene.instantiate()
		add_child_autofree(instance)
		var cc := instance as CharacterController
		assert_not_null(cc, "%s should extend CharacterController" % hero_id)
		if cc == null:
			continue
		assert_not_null(cc.hero_definition, "%s scene has no hero_definition" % hero_id)
		if cc.hero_definition != null:
			assert_eq(cc.hero_definition.hero_id, hero_id, "%s scene points at the wrong HeroDefinition" % hero_id)
			assert_not_null(cc.hero_definition.portrait, "%s HeroDefinition has no portrait" % hero_id)

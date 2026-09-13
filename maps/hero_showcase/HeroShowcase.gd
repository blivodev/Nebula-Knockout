extends Node2D
## Visual proof that the heroes' MCP-generated art is imported
## and renderable in-engine. Spawns one instance of each hero scene in a
## row, and a second row of true skeletal (Bone2D + AnimationPlayer)
## puppet rigs below them -- HeroRigAnimator's per-limb arm/leg animation,
## the hero-select/menu showcase puppeteering docs/ARCHITECTURE.md
## Section 3 reserves Skeleton2D rigs for. Run it with:
##   godot --path "D:\Projects\Nebula Knockout" res://maps/hero_showcase/HeroShowcase.tscn
## See docs/ART_STYLE.md for the pipeline that produced art/heroes/*.png.

const HERO_SCENES: Array[PackedScene] = [
	preload("res://entities/heroes/kael/Kael.tscn"),
	preload("res://entities/heroes/bastion/Bastion.tscn"),
	preload("res://entities/heroes/monk/Monk.tscn"),
	preload("res://entities/heroes/machinist/Machinist.tscn"),
	preload("res://entities/heroes/pyra/Pyra.tscn"),
	preload("res://entities/heroes/void/Void.tscn"),
	preload("res://entities/heroes/flint/Flint.tscn"),
	preload("res://entities/heroes/vex/Vex.tscn"),
]
## Matching hero ids/order to HERO_SCENES, purely for labeling + picking a
## per-hero rig tint below (thematic color, not read from any resource).
const HERO_IDS: Array[StringName] = [
	&"kael", &"bastion", &"monk", &"machinist", &"pyra", &"void", &"flint", &"vex",
]
const HERO_TINTS: Dictionary = {
	&"kael": Color(0.85, 0.35, 0.25),
	&"bastion": Color(0.3, 0.55, 0.85),
	&"monk": Color(0.9, 0.82, 0.4),
	&"machinist": Color(0.55, 0.58, 0.62),
	&"pyra": Color(1.0, 0.45, 0.15),
	&"void": Color(0.4, 0.2, 0.6),
	&"flint": Color(0.65, 0.52, 0.32),
	&"vex": Color(0.18, 0.75, 0.55),
}
const SPACING: float = 240.0
## Vertical offset from each hero's flat portrait down to its skeletal
## puppet rig, and the rig's on-screen scale (the placeholder limb art is
## authored in real pixel sizes, so this is just a display convenience).
const RIG_ROW_OFFSET: float = 220.0
const RIG_SCALE: float = 1.4

func _ready() -> void:
	# Keep the match loop idle so nothing spawns waves behind the showcase.
	MatchState.set_phase(MatchState.Phase.DRAFT)
	var start_x: float = -(HERO_SCENES.size() - 1) * SPACING * 0.5
	for i in range(HERO_SCENES.size()):
		var hero: Node2D = HERO_SCENES[i].instantiate()
		hero.position = Vector2(start_x + i * SPACING, 0.0)
		add_child(hero)
		_spawn_rig(HERO_IDS[i], Vector2(start_x + i * SPACING, RIG_ROW_OFFSET))

## Builds one HeroRigAnimator puppet (true Bone2D skeleton driven by a real
## AnimationPlayer) and starts it walking in place, for visual comparison
## against the flat portrait sprite above it.
func _spawn_rig(hero_id: StringName, at_position: Vector2) -> void:
	var tint: Color = HERO_TINTS.get(hero_id, Color.WHITE)
	var rig: Skeleton2D = HeroRigAnimator.build(str(hero_id), tint)
	rig.position = at_position + Vector2(0.0, HeroRigAnimator.total_height() * 0.5 * RIG_SCALE)
	rig.scale = Vector2.ONE * RIG_SCALE
	add_child(rig)
	var player: AnimationPlayer = rig.get_node("AnimationPlayer")
	player.play(&"walk")

	var label := Label.new()
	label.text = str(hero_id) + " (rig)"
	label.position = at_position + Vector2(-40.0, 40.0)
	add_child(label)

extends Node2D
## Visual proof that the heroes' MCP-generated art is imported
## and renderable in-engine. Spawns one instance of each hero scene in a
## row. Run it with:
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
const SPACING: float = 240.0

func _ready() -> void:
	# Keep the match loop idle so nothing spawns waves behind the showcase.
	MatchState.set_phase(MatchState.Phase.DRAFT)
	var start_x: float = -(HERO_SCENES.size() - 1) * SPACING * 0.5
	for i in range(HERO_SCENES.size()):
		var hero: Node2D = HERO_SCENES[i].instantiate()
		hero.position = Vector2(start_x + i * SPACING, 0.0)
		add_child(hero)

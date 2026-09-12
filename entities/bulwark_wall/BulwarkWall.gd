class_name BulwarkWall
extends StaticBody2D
## Temporary directional wall spawned by Bastion's Bulwark Wall. Blocks
## movement for its lifetime, then despawns.
##
## Simplification: a single StaticBody2D blocks BOTH teams, since one body
## cannot selectively collide per team. Making it enemy-only would need two
## bodies or a per-team collision layer scheme -- noted as follow-up in
## docs/ARCHITECTURE.md.

const STRUCTURES_LAYER_BIT: int = 6
const TEAM_A_LAYER_BIT: int = 1
const TEAM_B_LAYER_BIT: int = 2

@export var lifetime_sec: float = 4.0
@export var team: MatchState.Team = MatchState.Team.TEAM_A

@onready var visual: Polygon2D = $Visual

func _ready() -> void:
	set_collision_layer_value(STRUCTURES_LAYER_BIT, true)
	set_collision_mask_value(TEAM_A_LAYER_BIT, true)
	set_collision_mask_value(TEAM_B_LAYER_BIT, true)
	if visual != null:
		visual.color = Color(0.6, 0.85, 1.0, 0.75)
	get_tree().create_timer(lifetime_sec).timeout.connect(queue_free)

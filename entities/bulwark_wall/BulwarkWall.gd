class_name BulwarkWall
extends StaticBody2D
## Temporary directional wall spawned by Bastion's Bulwark Wall. Blocks
## ENEMY movement only, then despawns.
##
## Team-selective blocking works through dedicated per-team wall layers:
## a wall owned by Team A puts itself on layer 8 (wall_blocks_team_b),
## a wall owned by Team B on layer 7 (wall_blocks_team_a). Movers (heroes,
## minions) only mask the wall layer that corresponds to their own team,
## so allies pass through freely while enemies are blocked.

const LAYER_WALL_BLOCKS_A: int = 7 # occupied by TEAM_B-owned walls
const LAYER_WALL_BLOCKS_B: int = 8 # occupied by TEAM_A-owned walls

@export var lifetime_sec: float = 4.0
@export var team: MatchState.Team = MatchState.Team.TEAM_A

@onready var visual: Polygon2D = $Visual

func _ready() -> void:
	# Only the enemy-blocking layer is occupied; the wall's own mask stays
	# empty because blocking is resolved mover-side (mover.mask vs wall.layer).
	if team == MatchState.Team.TEAM_A:
		set_collision_layer_value(LAYER_WALL_BLOCKS_B, true)
	else:
		set_collision_layer_value(LAYER_WALL_BLOCKS_A, true)
	if visual != null:
		visual.color = Color(0.6, 0.85, 1.0, 0.75)
	get_tree().create_timer(lifetime_sec).timeout.connect(queue_free)

class_name ArenaVisuals
extends Node2D
## Procedurally renders the space environment, floating arena lane,
## glowing energy guard rails, base platforms, and center combat ring.
## Runs in _draw() with z_index = -10 so all gameplay nodes sit on top.

var _time: float = 0.0

# Deterministic star coordinates
var _stars: Array[Vector3] = [] # x, y, brightness

func _ready() -> void:
	z_index = -10
	# Generate 140 deterministic stars
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for i in range(140):
		var sx: float = rng.randf_range(-2200.0, 2200.0)
		var sy: float = rng.randf_range(-1300.0, 1300.0)
		var sz: float = rng.randf_range(0.3, 1.0)
		_stars.append(Vector3(sx, sy, sz))

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	# 1. Deep Space Void Backdrop
	draw_rect(Rect2(-2400.0, -1400.0, 4800.0, 2800.0), Color(0.04, 0.05, 0.08, 1.0))

	# 2. Twinkling Stars
	for star in _stars:
		var twinkle: float = star.z * (0.6 + 0.4 * sin(_time * 3.0 + star.x * 0.05))
		var col := Color(0.8, 0.9, 1.0, twinkle)
		draw_rect(Rect2(star.x, star.y, 2.5, 2.5), col)

	# 3. Soft Nebula Glows
	var neb_pulse: float = 0.5 + 0.2 * sin(_time * 0.8)
	draw_circle(Vector2(-500.0, -350.0), 320.0, Color(0.12, 0.25, 0.55, 0.12 * neb_pulse))
	draw_circle(Vector2(500.0, 350.0), 320.0, Color(0.55, 0.15, 0.25, 0.12 * neb_pulse))

	# 4. Arena Floating Platform Outer Substructure
	draw_rect(Rect2(-980.0, -225.0, 1960.0, 450.0), Color(0.07, 0.08, 0.13, 1.0))
	draw_rect(Rect2(-960.0, -215.0, 1920.0, 430.0), Color(0.09, 0.11, 0.17, 1.0))

	# 5. Main Walking Deck
	draw_rect(Rect2(-940.0, -200.0, 1880.0, 400.0), Color(0.13, 0.15, 0.21, 1.0))

	# 6. Decking Seam Panels (Vertical floor tiles)
	for x in range(-900, 920, 120):
		draw_line(Vector2(float(x), -198.0), Vector2(float(x), 198.0), Color(0.18, 0.21, 0.28, 0.6), 1.5)

	# 7. Team-Colored Lane Trim
	# Team A (Blue side: -940 to 0)
	draw_line(Vector2(-940.0, -196.0), Vector2(0.0, -196.0), Color(0.2, 0.65, 1.0, 0.85), 3.0)
	draw_line(Vector2(-940.0, 196.0), Vector2(0.0, 196.0), Color(0.2, 0.65, 1.0, 0.85), 3.0)
	# Team B (Red side: 0 to 940)
	draw_line(Vector2(0.0, -196.0), Vector2(940.0, -196.0), Color(1.0, 0.35, 0.35, 0.85), 3.0)
	draw_line(Vector2(0.0, 196.0), Vector2(940.0, 196.0), Color(1.0, 0.35, 0.35, 0.85), 3.0)

	# 8. Center Lane Division Strip
	for x in range(-760, 780, 40):
		var col := Color(0.3, 0.6, 0.9, 0.35) if x < 0 else Color(0.9, 0.4, 0.4, 0.35)
		draw_line(Vector2(float(x), 0.0), Vector2(float(x + 20), 0.0), col, 2.0)

	# 9. Center Combat Ring (Neutral Area at x=0)
	draw_circle(Vector2.ZERO, 150.0, Color(0.16, 0.18, 0.26, 0.7))
	draw_arc(Vector2.ZERO, 150.0, 0.0, TAU, 36, Color(0.7, 0.75, 0.85, 0.5), 2.0)
	draw_arc(Vector2.ZERO, 100.0, 0.0, TAU, 28, Color(0.5, 0.6, 0.8, 0.35), 1.5)
	draw_arc(Vector2.ZERO, 50.0, 0.0, TAU, 20, Color(0.9, 0.8, 0.3, 0.4), 1.5)

	# 10. Base A Platform Dais (-800, 0)
	var pos_a := Vector2(-800.0, 0.0)
	draw_circle(pos_a, 155.0, Color(0.10, 0.20, 0.35, 0.9))
	draw_arc(pos_a, 155.0, 0.0, TAU, 36, Color(0.2, 0.7, 1.0, 0.8), 3.0)
	draw_arc(pos_a, 120.0, 0.0, TAU, 28, Color(0.3, 0.8, 1.0, 0.5), 2.0)
	draw_arc(pos_a, 80.0, 0.0, TAU, 20, Color(0.4, 0.9, 1.0, 0.4), 1.5)
	# Energy conduits to lane
	draw_line(pos_a + Vector2(80, -40), pos_a + Vector2(160, -40), Color(0.2, 0.7, 1.0, 0.7), 2.0)
	draw_line(pos_a + Vector2(80, 40), pos_a + Vector2(160, 40), Color(0.2, 0.7, 1.0, 0.7), 2.0)

	# 11. Base B Platform Dais (+800, 0)
	var pos_b := Vector2(800.0, 0.0)
	draw_circle(pos_b, 155.0, Color(0.35, 0.12, 0.15, 0.9))
	draw_arc(pos_b, 155.0, 0.0, TAU, 36, Color(1.0, 0.35, 0.35, 0.8), 3.0)
	draw_arc(pos_b, 120.0, 0.0, TAU, 28, Color(1.0, 0.45, 0.45, 0.5), 2.0)
	draw_arc(pos_b, 80.0, 0.0, TAU, 20, Color(1.0, 0.55, 0.55, 0.4), 1.5)
	# Energy conduits to lane
	draw_line(pos_b - Vector2(80, -40), pos_b - Vector2(160, -40), Color(1.0, 0.35, 0.35, 0.7), 2.0)
	draw_line(pos_b - Vector2(80, 40), pos_b - Vector2(160, 40), Color(1.0, 0.35, 0.35, 0.7), 2.0)

	# 12. Rail Pylons Along Lane Edges
	for px in [-640.0, -420.0, -200.0, 0.0, 200.0, 420.0, 640.0]:
		var col_p := Color(0.25, 0.7, 1.0) if px < 0.0 else (Color(1.0, 0.4, 0.4) if px > 0.0 else Color(0.9, 0.85, 0.3))
		# Upper pylon
		draw_rect(Rect2(px - 6.0, -204.0, 12.0, 10.0), col_p)
		draw_circle(Vector2(px, -202.0), 3.5, Color.WHITE)
		# Lower pylon
		draw_rect(Rect2(px - 6.0, 194.0, 12.0, 10.0), col_p)
		draw_circle(Vector2(px, 202.0), 3.5, Color.WHITE)

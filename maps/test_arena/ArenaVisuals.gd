class_name ArenaVisuals
extends Node2D
## Procedurally renders the space environment, floating arena lane,
## glowing energy guard rails, base platforms, and center combat ring.
## Runs in _draw() with z_index = -10 so all gameplay nodes sit on top.
##
## Every shape is derived from lane_half_length / lane_half_width so the
## whole backdrop scales with whatever lane size TestArena is using
## (see configure()). The arena is deliberately larger than a single
## camera view -- players have to walk to see the rest of it instead of
## seeing it all at once.
##
## Depth is faked with true multi-layer parallax across 3 depth tiers
## (distant stars/planets, mid-depth nebulas, near-field debris fields --
## see `_parallax()` and the PARALLAX_* constants below), so distant
## layers visibly lag behind the camera pan while the foreground deck
## stays pinned to the real world coordinates gameplay nodes use.

## Fixed buffer of empty space (stars/nebula) kept around the walkable
## deck regardless of lane size, so the void frames the arena without
## growing disproportionately as the lane gets longer.
const BACKDROP_MARGIN_LENGTH: float = 5680.0
const BACKDROP_MARGIN_WIDTH: float = 1175.0

## Stars per world-unit^2, tuned so the original 800x200 lane still gets
## exactly 140 stars; scaled to whatever the current backdrop area is.
const STAR_DENSITY: float = 140.0 / (4800.0 * 2800.0)
const MIN_STARS: int = 80
const MAX_STARS: int = 400

## Planets and debris scale with backdrop area exactly like stars do (same
## reference lane/area), so a much larger arena (e.g. the 4x-expanded lane)
## still reads as a densely dressed void instead of a sparse one -- fixed
## counts tuned for the old, smaller lane would look empty once the
## backdrop area grows.
const PLANET_DENSITY: float = 5.0 / (4800.0 * 2800.0)
const MIN_PLANETS: int = 5
const MAX_PLANETS: int = 30
const DEBRIS_DENSITY: float = 22.0 / (4800.0 * 2800.0)
const MIN_DEBRIS: int = 22
const MAX_DEBRIS: int = 150

## Parallax factors, grouped into 3 depth tiers (plus the pinned foreground
## deck) so distant layers visibly lag behind the camera pan while nearer
## ones drift more -- the classic multi-layer parallax depth cue:
##   Tier 1 (farthest):  void backdrop + starfield + distant planets/moons
##   Tier 2 (mid-depth):  soft nebula gas clouds
##   Tier 3 (nearest):    tumbling asteroid/debris chunks
## 1.0 = pinned to the real world (no lag, used by the actual playable
## deck/rails so it always lines up with gameplay nodes); smaller values
## lag further behind the camera, reading as "further away".
# -- Tier 1: distant stars (+ void + planets) --
const PARALLAX_VOID: float = 0.04
const PARALLAX_STARS: float = 0.12
const PARALLAX_PLANETS: float = 0.22
# -- Tier 2: nebulas --
const PARALLAX_NEBULA: float = 0.32
# -- Tier 3: debris fields --
const PARALLAX_DEBRIS: float = 0.55
# -- Foreground (not a backdrop tier): the actual playable deck --
const PARALLAX_DECK: float = 1.0

@export var lane_half_length: float = 800.0
@export var lane_half_width: float = 200.0

var _time: float = 0.0

## The camera this backdrop parallaxes against. Set by TestArena after
## instancing so every layer's lag is measured from the same source of
## truth as what the player actually sees move.
var _camera: Camera2D = null

# Deterministic per-layer dressing, generated once in _generate_backdrop()
# and only regenerated when configure() picks a new lane size.
var _stars: Array[Vector3] = [] # x, y, brightness
var _planets: Array[Dictionary] = [] # {pos: Vector2, radius: float, color: Color, ring: bool}
var _debris: Array[Dictionary] = [] # {pos: Vector2, radius: float, spin: float, sides: int, drift: Vector2}

func _ready() -> void:
	z_index = -10
	_generate_backdrop()

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

## Called by TestArena before the first frame to match this backdrop to
## whatever lane dimensions the arena is actually using. Regenerates the
## backdrop dressing for the new size and forces a redraw.
func configure(new_half_length: float, new_half_width: float) -> void:
	lane_half_length = new_half_length
	lane_half_width = new_half_width
	_generate_backdrop()
	queue_redraw()

## Wires this backdrop to the camera the player actually sees through, so
## every parallax layer's lag is measured against real camera movement
## instead of assuming the camera never moves.
func set_camera(cam: Camera2D) -> void:
	_camera = cam

## Compensates a layer's draw position so it appears to move by only
## `factor` of the camera's actual travel. factor=1.0 (the foreground
## deck) yields zero compensation -- exactly what gameplay nodes use, so
## the deck always lines up with real bases/lanes. Smaller factors make a
## layer lag behind the camera, i.e. read as further away.
func _parallax(base: Vector2, factor: float) -> Vector2:
	if _camera == null or not is_instance_valid(_camera):
		return base
	return base + (1.0 - factor) * _camera.global_position

func _generate_backdrop() -> void:
	_generate_stars()
	_generate_planets()
	_generate_debris()

func _generate_stars() -> void:
	var backdrop_hl: float = lane_half_length + 180.0 + BACKDROP_MARGIN_LENGTH
	var backdrop_hw: float = lane_half_width + 25.0 + BACKDROP_MARGIN_WIDTH
	var area: float = (backdrop_hl * 2.0) * (backdrop_hw * 2.0)
	var star_count: int = clampi(int(round(STAR_DENSITY * area)), MIN_STARS, MAX_STARS)

	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	_stars.clear()
	for i in range(star_count):
		var sx: float = rng.randf_range(-(backdrop_hl - 200.0), backdrop_hl - 200.0)
		var sy: float = rng.randf_range(-(backdrop_hw - 100.0), backdrop_hw - 100.0)
		var sz: float = rng.randf_range(0.3, 1.0)
		_stars.append(Vector3(sx, sy, sz))

## A handful of large distant planets/moons scattered across the backdrop
## -- the "furthest" dressing layer besides the stars, drifting the least
## relative to the camera. Tier 1 (distant).
func _generate_planets() -> void:
	var backdrop_hl: float = lane_half_length + 180.0 + BACKDROP_MARGIN_LENGTH
	var backdrop_hw: float = lane_half_width + 25.0 + BACKDROP_MARGIN_WIDTH
	var area: float = (backdrop_hl * 2.0) * (backdrop_hw * 2.0)
	var planet_count: int = clampi(int(round(PLANET_DENSITY * area)), MIN_PLANETS, MAX_PLANETS)
	var palette: Array[Color] = [
		Color(0.35, 0.55, 0.95, 1.0), # ice blue
		Color(0.85, 0.35, 0.55, 1.0), # magenta
		Color(0.4, 0.85, 0.75, 1.0),  # teal
		Color(0.95, 0.6, 0.3, 1.0),   # ember orange
		Color(0.6, 0.5, 0.9, 1.0),    # violet
	]

	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	_planets.clear()
	for i in range(planet_count):
		var px: float = rng.randf_range(-(backdrop_hl - 260.0), backdrop_hl - 260.0)
		var py: float = rng.randf_range(-(backdrop_hw - 220.0), backdrop_hw - 220.0)
		var radius: float = rng.randf_range(60.0, 150.0)
		_planets.append({
			"pos": Vector2(px, py),
			"radius": radius,
			"color": palette[i % palette.size()],
			"ring": i % 2 == 0,
		})

## Small tumbling asteroid/debris chunks in the mid-distance, closer than
## the planets/nebula so they drift more with the camera and sell the
## depth of the layers behind them. Tier 3 (nearest backdrop layer).
func _generate_debris() -> void:
	var backdrop_hl: float = lane_half_length + 180.0 + BACKDROP_MARGIN_LENGTH * 0.7
	var backdrop_hw: float = lane_half_width + 25.0 + BACKDROP_MARGIN_WIDTH * 0.7
	var area: float = (backdrop_hl * 2.0) * (backdrop_hw * 2.0)
	var debris_count: int = clampi(int(round(DEBRIS_DENSITY * area)), MIN_DEBRIS, MAX_DEBRIS)

	var rng := RandomNumberGenerator.new()
	rng.seed = 7777
	_debris.clear()
	for i in range(debris_count):
		var dx: float = rng.randf_range(-backdrop_hl, backdrop_hl)
		var dy: float = rng.randf_range(-backdrop_hw, backdrop_hw)
		# Keep debris out of the actual playable deck/lane band.
		if absf(dy) < lane_half_width + 60.0:
			dy = sign(dy if dy != 0.0 else 1.0) * (lane_half_width + 60.0 + rng.randf_range(0.0, 80.0))
		_debris.append({
			"pos": Vector2(dx, dy),
			"radius": rng.randf_range(5.0, 16.0),
			"spin": rng.randf_range(0.15, 0.6) * (1.0 if rng.randf() > 0.5 else -1.0),
			"sides": rng.randi_range(5, 8),
			"drift": Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-2.0, 2.0)),
		})

func _draw() -> void:
	var hl: float = lane_half_length
	var hw: float = lane_half_width

	# Deck layer half-extents, each a fixed margin beyond the lane itself.
	var outer_hl: float = hl + 180.0
	var outer_hw: float = hw + 25.0
	var inset_hl: float = hl + 160.0
	var inset_hw: float = hw + 15.0
	var deck_hl: float = hl + 140.0
	var deck_hw: float = hw # main walking deck matches the lane width exactly

	var backdrop_hl: float = outer_hl + BACKDROP_MARGIN_LENGTH
	var backdrop_hw: float = outer_hw + BACKDROP_MARGIN_WIDTH

	_draw_void_layer(backdrop_hl, backdrop_hw)
	_draw_star_layer()
	_draw_planet_layer()
	_draw_nebula_layer(hl, hw)
	_draw_debris_layer()
	_draw_deck_layer(hl, hw, outer_hl, outer_hw, inset_hl, inset_hw, deck_hl, deck_hw)

## Layer 1: Deep Space Void Backdrop (furthest layer -- barely drifts).
func _draw_void_layer(backdrop_hl: float, backdrop_hw: float) -> void:
	var origin: Vector2 = _parallax(Vector2(-backdrop_hl, -backdrop_hw), PARALLAX_VOID)
	draw_rect(Rect2(origin, Vector2(backdrop_hl * 2.0, backdrop_hw * 2.0)), Color(0.04, 0.05, 0.08, 1.0))

## Layer 2: Twinkling Stars.
func _draw_star_layer() -> void:
	for star in _stars:
		var twinkle: float = star.z * (0.6 + 0.4 * sin(_time * 3.0 + star.x * 0.05))
		var col := Color(0.8, 0.9, 1.0, twinkle)
		var pos: Vector2 = _parallax(Vector2(star.x, star.y), PARALLAX_STARS)
		draw_rect(Rect2(pos, Vector2(2.5, 2.5)), col)

## Layer 3: Distant Planets/Moons, some with a faint ring, all with a soft
## atmospheric glow -- reads as further away than the nebula thanks to a
## lower parallax factor.
func _draw_planet_layer() -> void:
	for planet in _planets:
		var pos: Vector2 = _parallax(planet.pos, PARALLAX_PLANETS)
		var radius: float = planet.radius
		var color: Color = planet.color
		# Atmospheric glow halo.
		draw_circle(pos, radius * 1.35, Color(color.r, color.g, color.b, 0.10))
		draw_circle(pos, radius, Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, 0.9))
		draw_circle(pos, radius * 0.75, Color(color.r, color.g, color.b, 0.35))
		if planet.ring:
			draw_arc(pos, radius * 1.55, 0.0, PI * 2.0, 40, Color(color.r, color.g, color.b, 0.4), 3.0)

## Layer 4: Soft Nebula Glows.
func _draw_nebula_layer(hl: float, hw: float) -> void:
	var neb_pulse: float = 0.5 + 0.2 * sin(_time * 0.8)
	var pos_a: Vector2 = _parallax(Vector2(-hl * 0.625, -hw * 1.75), PARALLAX_NEBULA)
	var pos_b: Vector2 = _parallax(Vector2(hl * 0.625, hw * 1.75), PARALLAX_NEBULA)
	draw_circle(pos_a, 320.0, Color(0.12, 0.25, 0.55, 0.12 * neb_pulse))
	draw_circle(pos_b, 320.0, Color(0.55, 0.15, 0.25, 0.12 * neb_pulse))
	# A couple of extra, differently-colored nebula clouds further along
	# the lane so the void doesn't read as empty once the map got bigger.
	var pos_c: Vector2 = _parallax(Vector2(-hl * 1.35, hw * 2.4), PARALLAX_NEBULA)
	var pos_d: Vector2 = _parallax(Vector2(hl * 1.35, -hw * 2.4), PARALLAX_NEBULA)
	draw_circle(pos_c, 260.0, Color(0.2, 0.55, 0.4, 0.10 * neb_pulse))
	draw_circle(pos_d, 260.0, Color(0.5, 0.4, 0.15, 0.10 * neb_pulse))

## Layer 5: Tumbling asteroid/debris chunks -- the closest backdrop layer,
## so it drifts the most with the camera and sells the parallax depth of
## everything behind it.
func _draw_debris_layer() -> void:
	for rock in _debris:
		var drift_pos: Vector2 = rock.pos + rock.drift * sin(_time * 0.3 + rock.pos.x * 0.01)
		var pos: Vector2 = _parallax(drift_pos, PARALLAX_DEBRIS)
		var radius: float = rock.radius
		var sides: int = rock.sides
		var rot: float = _time * rock.spin
		var points := PackedVector2Array()
		for i in range(sides):
			var a: float = rot + (float(i) / float(sides)) * TAU
			var jitter: float = 0.8 + 0.2 * sin(a * 3.0 + rock.pos.y)
			points.append(pos + Vector2(cos(a), sin(a)) * radius * jitter)
		draw_colored_polygon(points, Color(0.32, 0.3, 0.34, 0.9))
		var outline: PackedVector2Array = points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, Color(0.5, 0.48, 0.55, 0.6), 1.0)

## Layers 6-12: the actual playable floating platform, deck, lane trim,
## combat ring, base dais platforms, and rail pylons. All pinned to the
## real world coordinates (PARALLAX_DECK = 1.0, i.e. no lag) since these
## must always line up with the bases/lane gameplay nodes actually use.
func _draw_deck_layer(hl: float, hw: float, outer_hl: float, outer_hw: float, inset_hl: float, inset_hw: float, deck_hl: float, deck_hw: float) -> void:
	# 6. Arena Floating Platform Outer Substructure
	draw_rect(Rect2(-outer_hl, -outer_hw, outer_hl * 2.0, outer_hw * 2.0), Color(0.07, 0.08, 0.13, 1.0))
	draw_rect(Rect2(-inset_hl, -inset_hw, inset_hl * 2.0, inset_hw * 2.0), Color(0.09, 0.11, 0.17, 1.0))

	# 7. Main Walking Deck
	draw_rect(Rect2(-deck_hl, -deck_hw, deck_hl * 2.0, deck_hw * 2.0), Color(0.13, 0.15, 0.21, 1.0))

	# 8. Decking Seam Panels (Vertical floor tiles)
	var seam_edge: int = int(deck_hl - 40.0)
	for x in range(-seam_edge, seam_edge + 20, 120):
		draw_line(Vector2(float(x), -(deck_hw - 2.0)), Vector2(float(x), deck_hw - 2.0), Color(0.18, 0.21, 0.28, 0.6), 1.5)

	# 9. Team-Colored Lane Trim
	var trim_y: float = deck_hw - 4.0
	# Team A (Blue side: -deck_hl to 0)
	draw_line(Vector2(-deck_hl, -trim_y), Vector2(0.0, -trim_y), Color(0.2, 0.65, 1.0, 0.85), 3.0)
	draw_line(Vector2(-deck_hl, trim_y), Vector2(0.0, trim_y), Color(0.2, 0.65, 1.0, 0.85), 3.0)
	# Team B (Red side: 0 to deck_hl)
	draw_line(Vector2(0.0, -trim_y), Vector2(deck_hl, -trim_y), Color(1.0, 0.35, 0.35, 0.85), 3.0)
	draw_line(Vector2(0.0, trim_y), Vector2(deck_hl, trim_y), Color(1.0, 0.35, 0.35, 0.85), 3.0)

	# 10. Center Lane Division Strip
	var lane_edge: int = int(hl - 40.0)
	for x in range(-lane_edge, lane_edge + 20, 40):
		var col := Color(0.3, 0.6, 0.9, 0.35) if x < 0 else Color(0.9, 0.4, 0.4, 0.35)
		draw_line(Vector2(float(x), 0.0), Vector2(float(x + 20), 0.0), col, 2.0)

	# 11. Center Combat Ring (Neutral Area at x=0)
	draw_circle(Vector2.ZERO, 150.0, Color(0.16, 0.18, 0.26, 0.7))
	draw_arc(Vector2.ZERO, 150.0, 0.0, TAU, 36, Color(0.7, 0.75, 0.85, 0.5), 2.0)
	draw_arc(Vector2.ZERO, 100.0, 0.0, TAU, 28, Color(0.5, 0.6, 0.8, 0.35), 1.5)
	draw_arc(Vector2.ZERO, 50.0, 0.0, TAU, 20, Color(0.9, 0.8, 0.3, 0.4), 1.5)

	# 12. Base A Platform Dais (-hl, 0)
	var pos_a := Vector2(-hl, 0.0)
	draw_circle(pos_a, 155.0, Color(0.10, 0.20, 0.35, 0.9))
	draw_arc(pos_a, 155.0, 0.0, TAU, 36, Color(0.2, 0.7, 1.0, 0.8), 3.0)
	draw_arc(pos_a, 120.0, 0.0, TAU, 28, Color(0.3, 0.8, 1.0, 0.5), 2.0)
	draw_arc(pos_a, 80.0, 0.0, TAU, 20, Color(0.4, 0.9, 1.0, 0.4), 1.5)
	# Energy conduits to lane
	draw_line(pos_a + Vector2(80, -40), pos_a + Vector2(160, -40), Color(0.2, 0.7, 1.0, 0.7), 2.0)
	draw_line(pos_a + Vector2(80, 40), pos_a + Vector2(160, 40), Color(0.2, 0.7, 1.0, 0.7), 2.0)

	# 13. Base B Platform Dais (+hl, 0)
	var pos_b := Vector2(hl, 0.0)
	draw_circle(pos_b, 155.0, Color(0.35, 0.12, 0.15, 0.9))
	draw_arc(pos_b, 155.0, 0.0, TAU, 36, Color(1.0, 0.35, 0.35, 0.8), 3.0)
	draw_arc(pos_b, 120.0, 0.0, TAU, 28, Color(1.0, 0.45, 0.45, 0.5), 2.0)
	draw_arc(pos_b, 80.0, 0.0, TAU, 20, Color(1.0, 0.55, 0.55, 0.4), 1.5)
	# Energy conduits to lane
	draw_line(pos_b - Vector2(80, -40), pos_b - Vector2(160, -40), Color(1.0, 0.35, 0.35, 0.7), 2.0)
	draw_line(pos_b - Vector2(80, 40), pos_b - Vector2(160, 40), Color(1.0, 0.35, 0.35, 0.7), 2.0)

	# 14. Rail Pylons Along Lane Edges (evenly spread across the lane)
	for frac in [-0.8, -0.525, -0.25, 0.0, 0.25, 0.525, 0.8]:
		var px: float = frac * hl
		var col_p := Color(0.25, 0.7, 1.0) if px < 0.0 else (Color(1.0, 0.4, 0.4) if px > 0.0 else Color(0.9, 0.85, 0.3))
		# Upper pylon
		draw_rect(Rect2(px - 6.0, -(hw + 4.0), 12.0, 10.0), col_p)
		draw_circle(Vector2(px, -(hw + 2.0)), 3.5, Color.WHITE)
		# Lower pylon
		draw_rect(Rect2(px - 6.0, hw - 6.0, 12.0, 10.0), col_p)
		draw_circle(Vector2(px, hw + 2.0), 3.5, Color.WHITE)

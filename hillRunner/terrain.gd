extends Node2D
## Endless Tiny Wings-style hills.
## Alternating peak/valley key points joined with cosine curves, so slopes are
## flat at every top and bottom. Built in chunks just ahead of the camera.

@export var chunk_width := 2048.0
@export var step := 12.0            ## px between collision points
@export var base_y := 400.0
@export var hill_width := Vector2(380.0, 700.0)   ## min, max (half a hill: peak->valley)
@export var start_amp := Vector2(40.0, 100.0)     ## amplitude range at the start
@export var end_amp := Vector2(150.0, 320.0)      ## amplitude range far away
@export var ramp_distance := 60000.0              ## px until hills reach end_amp
@export var depth := 3000.0

var _xs := PackedFloat32Array()
var _ys := PackedFloat32Array()
var _chunks := {}
var _rng := RandomNumberGenerator.new()
var _peak_next := true

const COLORS := [
	Color("#9fd3ec"), Color("#b7e0f2"), Color("#8cc4e3"),
	Color("#a8d8ee"), Color("#c3e6f5"), Color("#94cbe8"),
]


func _ready() -> void:
	_rng.randomize()
	# Start with a valley behind the player and a peak at x = 0 to roll off.
	_xs.append(-900.0); _ys.append(base_y + 80.0)
	_xs.append(0.0);    _ys.append(base_y - 280.0)
	_peak_next = false


func height_at(x: float) -> float:
	_ensure_keys(x + 1.0)
	var i := _xs.bsearch(x)
	if i <= 0:
		return _ys[0]
	var x0 := _xs[i - 1]
	var x1 := _xs[i]
	var t := (x - x0) / (x1 - x0)
	var mu := (1.0 - cos(t * PI)) * 0.5
	return lerpf(_ys[i - 1], _ys[i], mu)


func update_view(center_x: float) -> void:
	var first := int(floor((center_x - chunk_width) / chunk_width))
	var last := int(floor((center_x + chunk_width * 2.0) / chunk_width))
	for i in range(first, last + 1):
		if not _chunks.has(i):
			_chunks[i] = _build_chunk(i)
	for i in _chunks.keys():
		if i < first or i > last:
			_chunks[i].queue_free()
			_chunks.erase(i)


func _ensure_keys(to_x: float) -> void:
	while _xs[_xs.size() - 1] < to_x:
		var last_x := _xs[_xs.size() - 1]
		var k := clampf(last_x / ramp_distance, 0.0, 1.0)
		var lo := lerpf(start_amp.x, end_amp.x, k)
		var hi := lerpf(start_amp.y, end_amp.y, k)
		var amp := _rng.randf_range(lo, hi)
		var w := _rng.randf_range(hill_width.x, hill_width.y)
		_xs.append(last_x + w)
		_ys.append(base_y - amp if _peak_next else base_y + amp * 0.6)
		_peak_next = not _peak_next


func _build_chunk(index: int) -> StaticBody2D:
	var x0 := index * chunk_width
	var x1 := x0 + chunk_width
	_ensure_keys(x1 + 1.0)

	var top := PackedVector2Array()
	var x := x0
	while x < x1:
		top.append(Vector2(x, height_at(x)))
		x += step
	top.append(Vector2(x1, height_at(x1)))

	var poly := top.duplicate()
	poly.append(Vector2(x1, base_y + depth))
	poly.append(Vector2(x0, base_y + depth))

	var body := StaticBody2D.new()
	var mat := PhysicsMaterial.new()
	mat.friction = 0.0
	mat.bounce = 0.0
	body.physics_material_override = mat

	var col := CollisionPolygon2D.new()
	col.polygon = poly
	body.add_child(col)

	var fill := Polygon2D.new()
	fill.polygon = poly
	fill.color = COLORS[posmod(index, COLORS.size())]
	body.add_child(fill)

	# Ice: a glossy white crust plus a thin blue shine line just below it.
	var shine := Line2D.new()
	shine.points = top
	shine.position = Vector2(0, 14)
	shine.width = 6.0
	shine.default_color = Color(1, 1, 1, 0.35)
	shine.joint_mode = Line2D.LINE_JOINT_ROUND
	body.add_child(shine)

	var edge := Line2D.new()
	edge.points = top
	edge.width = 9.0
	edge.default_color = Color("#f4fbff")
	edge.joint_mode = Line2D.LINE_JOINT_ROUND
	body.add_child(edge)

	add_child(body)
	return body

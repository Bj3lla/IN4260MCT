class_name Hills
extends Node2D
## Responsibility: an endless path of hills and valleys.
##
## Alternating peak / valley key points are joined with cosine curves, so the
## slope is flat at every top and bottom. Chunks of the path are built just
## around what the screen shows and freed again behind it. Works for the
## collidable main course and for non-colliding parallax layers: it works out
## which local x range is visible through its own canvas transform.
##
## Defaults are tuned for a back ridge. Terrain overrides them for the main course.

@export_group("Shape")
@export var chunk_width := 2048.0
@export var step := 32.0                           ## px between points (~12 when colliding)
@export var base_y := 330.0
@export var hill_width := Vector2(900.0, 1400.0)   ## half a hill: peak -> valley
@export var start_amp := Vector2(30.0, 60.0)
@export var end_amp := Vector2(30.0, 60.0)         ## equal to start_amp = no difficulty ramp
@export var ramp_distance := 60000.0               ## px until hills reach end_amp
@export var depth := 4000.0
## Start with a valley behind x = 0 and a big peak at x = 0 to roll off.
@export var intro_hill := false

@export_group("Look")
@export var fill_color := Color("#B9B4D1")
@export var edge_color := Color("#FFF4D8")
@export var edge_width := 0.0                      ## 0 = no border line
@export var chunk_overlap := 2.0                   ## hides hairline seams between chunks

@export_group("Physics")
@export var has_collision := false

var _xs := PackedFloat32Array()
var _ys := PackedFloat32Array()
var _chunks := {}
var _rng := RandomNumberGenerator.new()
var _peak_next := true


func _ready() -> void:
	_rng.randomize()
	if intro_hill:
		_xs.append(-900.0); _ys.append(base_y + 80.0)
		_xs.append(0.0);    _ys.append(base_y - 280.0)
		_peak_next = false
	else:
		# Start far to the left so the screen is covered from the first frame.
		_xs.append(-3000.0); _ys.append(base_y)
		_peak_next = true


func _process(_delta: float) -> void:
	var to_local := get_global_transform_with_canvas().affine_inverse()
	var size := get_viewport_rect().size
	update_view((to_local * Vector2(0.0, size.y * 0.5)).x, (to_local * Vector2(size.x, size.y * 0.5)).x)


## Height of the path at local x.
func height_at(x: float) -> float:
	_ensure_keys(x + 1.0)
	var i := _xs.bsearch(x)
	if i <= 0:
		return _ys[0]
	var t := (x - _xs[i - 1]) / (_xs[i] - _xs[i - 1])
	var mu := (1.0 - cos(t * PI)) * 0.5     # cosine easing: flat at peaks and valleys
	return lerpf(_ys[i - 1], _ys[i], mu)


## Make sure chunks exist for [left_x, right_x] (plus a margin) and free the rest.
func update_view(left_x: float, right_x: float) -> void:
	var first := int(floor(left_x / chunk_width)) - 1
	var last := int(floor(right_x / chunk_width)) + 1
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
		var amp := _rng.randf_range(lerpf(start_amp.x, end_amp.x, k), lerpf(start_amp.y, end_amp.y, k))
		var w := _rng.randf_range(hill_width.x, hill_width.y)
		_xs.append(last_x + w)
		_ys.append(base_y - amp if _peak_next else base_y + amp * 0.6)
		_peak_next = not _peak_next


func _build_chunk(index: int) -> Node2D:
	var x0 := index * chunk_width
	var x1 := x0 + chunk_width + chunk_overlap
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

	var holder: Node2D
	if has_collision:
		var body := StaticBody2D.new()
		body.physics_material_override = Ice.material()
		var col := CollisionPolygon2D.new()
		col.polygon = poly
		body.add_child(col)
		holder = body
	else:
		holder = Node2D.new()

	var fill := Polygon2D.new()
	fill.polygon = poly
	fill.color = fill_color
	holder.add_child(fill)

	if edge_width > 0.0:
		var edge := Line2D.new()
		edge.points = top
		edge.width = edge_width
		edge.default_color = edge_color
		edge.joint_mode = Line2D.LINE_JOINT_ROUND
		edge.begin_cap_mode = Line2D.LINE_CAP_ROUND
		edge.end_cap_mode = Line2D.LINE_CAP_ROUND
		holder.add_child(edge)

	add_child(holder)
	return holder

class_name Track
extends Hills
## Responsibility: the main course preset. Collidable, sand-coloured with a
## light border, and hills that grow with distance.

func _init() -> void:
	has_collision = true #main course has collision on
	intro_hill = true
	step = 12.0
	base_y = 400.0
	hill_width = Vector2(380.0, 700.0)
	start_amp = Vector2(40.0, 100.0)
	end_amp = Vector2(150.0, 320.0)
	ramp_distance = 60000.0
	depth = 3000.0
	fill_color = Color("#EDE3C9")
	edge_color = Color("#FFF4D8")
	edge_width = 9.0

@export_group("Collectables")
@export var collectable_chance := 0.4      ## chance that a valley gets a collectable
@export var collectable_height := 30.0     ## pickup centre above the valley floor
@export var collectable_start_x := 1500.0  ## none before this x, so the start stays clean


func _build_chunk(index: int) -> Node2D:
	var holder := super._build_chunk(index)   # hills, collision and visuals as before

	# Each key point belongs to exactly one chunk (no overlap), so no doubles.
	var x0 := index * chunk_width
	var x1 := x0 + chunk_width
	var i := _xs.bsearch(x0)
	while i < _xs.size() and _xs[i] < x1:
		var x := _xs[i]
		var is_valley := _ys[i] > base_y   # peaks are above base_y, valleys below
		if is_valley and x >= collectable_start_x and _rng.randf() < collectable_chance:
			var c := Collectable.new()
			c.position = Vector2(x, _ys[i] - collectable_height)
			holder.add_child(c)
		i += 1
	return holder

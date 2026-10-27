class_name Terrain
extends Hills
## Responsibility: the main course preset. Collidable, sand-coloured with a
## light border, and hills that grow with distance.

func _init() -> void:
	has_collision = true
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

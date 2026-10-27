class_name Scenery
extends Node2D
## Responsibility: the parallax ridges. Three background layers (back to
## front) and one foreground layer, each an endless Hills generator inside a
## Parallax2D. Add this node BEFORE the terrain so the background draws
## behind it; the foreground uses a high z_index to draw over everything.
##
## `screen_y` is where the ridge's baseline sits on screen (0 = top, 1 = bottom)
## when the camera is at the reference position below. A far layer is nearly
## screen-locked, so its local y is relative to the screen centre rather than
## the world; this converts a screen position into the right base_y.
## Requires Godot 4.3+ (Parallax2D).

const REFERENCE_CAMERA_Y := 350.0
const REFERENCE_ZOOM := 0.8

const LAYERS := [
	{ "scroll": Vector2(0.05, 0.1), "color": Color("#B9B4D1"), "screen_y": 0.80,
	  "width": Vector2(1500, 3000), "amp": Vector2(30, 60) },
	{ "scroll": Vector2(0.1, 0.1), "color": Color("#A5A1BA"), "screen_y": 0.90,
	  "width": Vector2(1200, 2800), "amp": Vector2(40, 80) },
	{ "scroll": Vector2(0.2, 0.1), "color": Color("#9290AB"), "screen_y": 1,
	  "width": Vector2(1000, 1500), "amp": Vector2(50, 100) },
	{ "scroll": Vector2(1.2, 1.0), "color": Color("#B4A88B"), "screen_y": 0.95,
	  "width": Vector2(600, 1000), "amp": Vector2(20, 50), "z": 10 },
]


func _ready() -> void:
	for cfg in LAYERS:
		add_child(_make_layer(cfg))


func _make_layer(cfg: Dictionary) -> Parallax2D:
	var scroll: Vector2 = cfg["scroll"]

	var hills := Hills.new()
	hills.fill_color = cfg["color"]
	hills.hill_width = cfg["width"]
	hills.start_amp = cfg["amp"]
	hills.end_amp = cfg["amp"]
	hills.base_y = _base_y_for(cfg["screen_y"], scroll.y)

	var layer := Parallax2D.new()
	layer.scroll_scale = scroll
	layer.z_index = cfg.get("z", 0)
	layer.add_child(hills)
	return layer


func _base_y_for(screen_y: float, scroll_y: float) -> float:
	var viewport_h := get_viewport_rect().size.y
	return (screen_y - 0.5) * viewport_h / REFERENCE_ZOOM + scroll_y * REFERENCE_CAMERA_Y

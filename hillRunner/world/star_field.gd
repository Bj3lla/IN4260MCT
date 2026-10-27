class_name StarField
extends Parallax2D

const STARS_PATH := "res://visuals/Quiet starfield.svg" 
const SCROLL := Vector2(0.05, 0)
const TILE_SCALE := 0.5 # raise if the stars are too small
const REPEAT_Y := true
const REPEATS := 8


func _ready() -> void:
	var texture := load(STARS_PATH) as Texture2D
	if texture == null:
		push_warning("StarField: no texture at %s" % STARS_PATH)
		return

	scroll_scale = SCROLL
	z_index = -100

	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2.ONE * TILE_SCALE
	add_child(sprite)

	var tile := texture.get_size() * TILE_SCALE
	repeat_size = Vector2(tile.x, tile.y if REPEAT_Y else 0.0)
	repeat_times = REPEATS

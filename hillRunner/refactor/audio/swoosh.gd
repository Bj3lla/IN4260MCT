extends AudioStreamPlayer
## Looping swoosh. Higher on screen = quieter/lower, lower on screen = louder/higher.
## Also gets louder the faster the ball moves.

@export var player: Player
@export var pitch_top := 0.85
@export var pitch_bottom := 1.15
@export var volume_top_db := -18.0
@export var volume_bottom_db := -6.0
@export var smoothing := 8.0


func _ready() -> void:
	play()


func _process(delta: float) -> void:
	var ball := player.ball
	if not is_instance_valid(ball):
		return

	# 0 at the top of the screen, 1 at the bottom
	var screen_y := ball.get_global_transform_with_canvas().origin.y
	var height := clampf(screen_y / get_viewport().get_visible_rect().size.y, 0.0, 1.0)
	# 0 when still, 1 at the ball's max speed
	var speed := clampf(ball.linear_velocity.length() / ball.max_speed, 0.0, 1.0)

	var target_pitch := lerpf(pitch_top, pitch_bottom, height)
	var target_volume := lerpf(volume_top_db, volume_bottom_db, height) + linear_to_db(maxf(speed, 0.01))

	var k := 1.0 - exp(-smoothing * delta)
	pitch_scale = lerpf(pitch_scale, target_pitch, k)
	volume_db = lerpf(volume_db, target_volume, k)

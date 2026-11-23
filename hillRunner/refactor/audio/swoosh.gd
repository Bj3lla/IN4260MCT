extends AudioStreamPlayer
## A 'static' white noise sound is looping endlessly, and being controlled dynamically
## by the players position and speed to create a 'swoosh' kind of sound. 
## Higher on screen = quieter/lower, lower on screen = louder/higher. Also gets louder the faster the ball moves.

@export var player: Player
@export var pitch_top := 0.5
@export var pitch_bottom := 2
@export var volume_top_db := -32.0 #volume when ball is at the top of the screen
@export var volume_bottom_db := 12 #volume when ball is at the bottom of the screen
@export var smoothing := 12.0 #higher = more snappy pitch and volume changess. lower = softer and slower


func _ready() -> void:
	play() #important: loop must be enabled for the "swoosh"/"white noise" sample


func _process(delta: float) -> void:
	var ball := player.ball 
	if not is_instance_valid(ball):
		return

	var screen_y := ball.get_global_transform_with_canvas().origin.y
	var height := clampf(screen_y / get_viewport().get_visible_rect().size.y, 0.0, 1.0) # 0 at the top of the screen, 1 at the bottom
	
	var speed := clampf(ball.linear_velocity.length() / ball.max_speed, 0.0, 1.0) # 0 when still, 1 at the ball's max speed

	var target_pitch := lerpf(pitch_top, pitch_bottom, height) #calculate pitch from players y position/height
	var target_volume := lerpf(volume_top_db, volume_bottom_db, height) + linear_to_db(maxf(speed, 0.01)) #calculate volume from both players height and speed
	
	if not ball.on_ground: target_volume -= 12.0 # prevent swoosh sound from playing while in air (tune it down by 12 db)
	
	var k := 1.0 - exp(-smoothing * delta) #how 'fast' the smoothing is
	pitch_scale = lerpf(pitch_scale, target_pitch, k) #tunes pitch smootly towards target pitch
	volume_db = lerpf(volume_db, target_volume, k) #tunes volume smootly towards target volume

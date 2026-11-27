class_name Player
extends Node2D
## Spawns a RigidBall or SoftBall at this
## node's position and swaps between them with B, continuing from where the old
## ball was. The balls read InputProcessing.dive themselves. Restarting the run
## is the game's job (main.gd).

signal ball_changed(ball: PlayerPhysics)        ## e.g. for the camera to follow the new ball
signal landed(kind: String, change: float)      ## relayed from whichever ball is active, kind kan be "bad", "good", or "great", change is speedchange
signal collected(amount: float) ## e.g. for a sound and/or hud flash 

const SOFT_BALL_SCENE := preload("res://refactor/player/bodies/soft_ball/soft_ball.tscn")
const SWAP_LIFT := Vector2(0.0, -20.0)          ## spawn a swapped ball slightly higher, clear of the ground
const SPAWN_HEIGHT := 80.0     ## ball spawns this far above the ground

@export var track: Track
## Which ball to spawn. Static, so it is kept across restarts (scene reloads).
static var use_soft_ball := false
@export var boost_time := 3.0  ## seconds of boost in a full bar

# NEW: float meter
# float meter
@export var float_half_life := 0.3   ## seconds of full float until the lift is halved
@export var float_grace := 0.4       ## seconds of full-strength float (the catch) before it starts fading

var float_left := 1.0                ## 0..1, reset on every takeoff
var _float_held := 0.0               ## seconds floated since takeoff
var _was_on_ground := true

var ball: PlayerPhysics
var boost := 1.0               ## boost left for this run, 0..1

func _ready() -> void:
	global_position.y = track.height_at(global_position.x) - SPAWN_HEIGHT
	_spawn(global_position)


func _physics_process(delta: float) -> void:
	ball.boosting = InputProcessing.boosting and boost > 0.0
	if ball.boosting:
		boost = maxf(boost - delta / boost_time, 0.0)

	# Fresh float on every takeoff (launching off a hill, a bump, a bounce).
	if _was_on_ground and not ball.on_ground:
		float_left = 1.0
		_float_held = 0.0
	_was_on_ground = ball.on_ground

	var floating := clampf(-InputProcessing.dive, 0.0, 1.0)
	if not ball.on_ground and floating > 0.0:
		_float_held += floating * delta
		if _float_held > float_grace:   # catch is done, now fade exponentially
			float_left *= pow(0.5, floating * delta / float_half_life)
	ball.float_strength = float_left


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("swap_ball"):
		use_soft_ball = not use_soft_ball
		_spawn(ball.global_position + SWAP_LIFT)
		get_viewport().set_input_as_handled()


func _spawn(at: Vector2) -> void:
	if ball:
		remove_child(ball)   # leave the physics world now, so the new ball doesn't collide with it
		ball.queue_free()

	if use_soft_ball:
		ball = SOFT_BALL_SCENE.instantiate()
	else:
		ball = RigidBall.new()
	ball.position = to_local(at)
	add_child(ball)
	ball.landed.connect(landed.emit)
	ball_changed.emit(ball)

func add_boost(amount: float) -> void:
	boost = minf(boost + amount, 1.0)
	collected.emit(amount)

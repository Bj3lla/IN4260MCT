class_name Player
extends Node2D
## Spawns a RigidBall or SoftBall at this
## node's position and swaps between them with B, continuing from where the old
## ball was. The balls read InputProcessing.dive themselves. Restarting the run
## is the game's job (main.gd).

signal ball_changed(ball: PlayerPhysics)        ## e.g. for the camera to follow the new ball
signal landed(kind: String, change: float)      ## relayed from whichever ball is active

const SOFT_BALL_SCENE := preload("res://refactor/player/bodies/soft_ball/soft_ball.tscn")
const SWAP_LIFT := Vector2(0.0, -20.0)          ## spawn a swapped ball slightly higher, clear of the ground

## Which ball to spawn. Static, so it is kept across restarts (scene reloads).
static var use_soft_ball := false

var ball: PlayerPhysics


func _ready() -> void:
	_spawn(global_position)


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

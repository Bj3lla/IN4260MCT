class_name Player
extends Node2D
## Spawns the chosen ball (RigidBall or SoftBall) at this
## node's position, swaps between them with B and respawns at the start with R.
## The balls read InputProcessing.dive themselves; the rest of the game only
## needs `ball` (position, linear_velocity, on_ground) and the signals below.

signal ball_changed(ball: PlayerPhysics)        ## e.g. for the camera to follow the new ball
signal landed(kind: String, change: float)      ## relayed from whichever ball is active

@export var rigid_ball_scene: PackedScene      ## scene with a RigidBall root
@export var soft_ball_scene: PackedScene       ## scene with a SoftBall root (needs its sfx_jump child)
@export var start_with_soft_ball := true

var ball: PlayerPhysics
var _use_soft := true


func _ready() -> void:
	_use_soft = start_with_soft_ball
	_spawn(global_position)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("swap_ball"):
		_use_soft = not _use_soft
		_spawn(ball.global_position)   # carry on from where the old ball was
	elif event.is_action_pressed("restart"):
		_spawn(global_position)


func _spawn(at: Vector2) -> void:
	if ball:
		remove_child(ball)   # leave the physics world now, so the new ball doesn't collide with it
		ball.queue_free()

	var scene := soft_ball_scene if _use_soft else rigid_ball_scene
	ball = scene.instantiate() as PlayerPhysics
	ball.position = to_local(at)
	add_child(ball)
	ball.landed.connect(landed.emit)
	ball_changed.emit(ball)

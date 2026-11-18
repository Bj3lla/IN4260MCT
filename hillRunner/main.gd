extends Node2D
## Assembles the scene and handle restart. Ball logic is kept in Player.gd
## Everything else lives in its own class: StarField, Scenery, Track, Player
## (which owns the ball and the ball swap), Camera and Hud.

const PIXELS_PER_METER := 100.0

@onready var _world : World = $World
@onready var _player: Player = $Player
@onready var _hud: Hud = $Hud

var _start_x := 0.0
var _best_m := 0.0


func _ready() -> void:

	_start_x = _player.global_position.x
	
	var camera := Camera.new()
	camera.target = _player.ball
	camera.track = _world.track
	add_child(camera)
	_player.ball_changed.connect(func(ball: PlayerPhysics) -> void: camera.target = ball)

	_player.landed.connect(_hud.show_landing)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _process(_delta: float) -> void:
	var ball := _player.ball
	_best_m = maxf(_best_m, (ball.global_position.x - _start_x) / PIXELS_PER_METER)
	_hud.show_stats(_best_m, ball.linear_velocity.length(), ball is SoftBall)

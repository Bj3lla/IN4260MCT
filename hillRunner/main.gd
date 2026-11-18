extends Node2D
## Main scene: creates the Camera, connects Player, World and Hud, tracks the
## best distance (in meters) for the Hud, and reloads the scene on restart (R).

const PIXELS_PER_METER := 100.0
const SKY_COLOR := Color("#3a3166")

@onready var _player: Player = $Player
@onready var _hud: Hud = $Hud
@onready var _camera: Camera = $Camera

var _start_x := 0.0
var _best_m := 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(SKY_COLOR)
	_start_x = _player.global_position.x #where the run starts
	
	_camera.target = _player.ball #camera follows the ball
	_player.ball_changed.connect(func(ball: PlayerPhysics) -> void: _camera.target = ball) #camera updates reference ball when switching to another ball (key B)
	
	_player.landed.connect(_hud.show_landing) #shows "Great landing!" or "Bad landing"
	

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _process(_delta: float) -> void:
	var ball := _player.ball
	_best_m = maxf(_best_m, (ball.global_position.x - _start_x) / PIXELS_PER_METER) #updates distance traveled
	_hud.show_stats(_best_m, ball.linear_velocity.length(), ball is SoftBall)

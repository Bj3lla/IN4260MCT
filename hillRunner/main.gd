class_name Main
extends Node2D
## Main scene: creates the Camera, connects Player, World and Hud, tracks the
## best distance (in meters) for the Hud, and reloads the scene on restart (R).
## Esc returns to the main menu. In timed mode the run ends after RUN_TIME
## seconds: the Hud shows the distance and the game pauses.

const PIXELS_PER_METER := 100.0
const SKY_COLOR := Color("#3a3166")
const MENU_SCENE := "res://refactor/main_menu/main_menu.tscn"
const RUN_TIME := 60.0

## Set by the main menu. Static, so it is kept across restarts (scene reloads).
static var timed := false

@onready var _player: Player = $Player
@onready var _hud: Hud = $Hud
@onready var _camera: Camera = $Camera
@onready var _music: AudioStreamPlayer = $Music

var _start_x := 0.0
var _best_m := 0.0
var _time_left := RUN_TIME


func _ready() -> void:
	RenderingServer.set_default_clear_color(SKY_COLOR)
	_start_x = _player.global_position.x #where the run starts

	_camera.target = _player.ball #camera follows the ball
	_player.ball_changed.connect(func(ball: PlayerPhysics) -> void: _camera.target = ball) #camera updates reference ball when switching to another ball (key B)

	_player.landed.connect(_hud.show_landing) #shows "Great landing!" or "Bad landing"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().paused = false #a finished timed run is paused
		get_tree().reload_current_scene()
	elif event.is_action_pressed("ui_cancel"):
		get_tree().paused = false
		get_tree().change_scene_to_file(MENU_SCENE)


func _process(delta: float) -> void:
	if timed and _time_left == 0.0:
		_hud.show_result(_best_m)
		_music.stream_paused = true
		get_tree().paused = true #World, Player and Camera are pausable, Main and Hud keep running
		return
		
	var ball := _player.ball
	_best_m = maxf(_best_m, (ball.global_position.x - _start_x) / PIXELS_PER_METER) #updates distance traveled
	if timed:
		_time_left = maxf(_time_left - delta, 0.0)
	_hud.show_stats(_best_m, _player.boost, _time_left if timed else -1.0)

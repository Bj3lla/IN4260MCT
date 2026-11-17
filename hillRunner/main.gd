extends Node2D
## Assembles the scene and handle restart. Ball logic is kept in Player.gd
## Everything else lives in its own class: StarField, Scenery, Track, Player
## (which owns the ball and the ball swap), Camera and Hud.

const SKY_COLOR := Color("#3a3166")
const PIXELS_PER_METER := 100.0

var _player: Player
var _hud: Hud
var _start_x := 0.0
var _best_m := 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(SKY_COLOR)
	add_child(StarField.new())   # stars first: furthest back in the background
	add_child(Scenery.new())     # background hills, must come before the track

	var track := Track.new()
	add_child(track)

	_player = Player.new()
	_player.position = Vector2(0.0, track.height_at(0.0) - 80.0)   # the ball spawns here
	add_child(_player)
	_start_x = _player.position.x

	var camera := Camera.new()
	camera.target = _player.ball
	camera.track = track
	add_child(camera)
	_player.ball_changed.connect(func(ball: PlayerPhysics) -> void: camera.target = ball)

	_hud = Hud.new()
	add_child(_hud)
	_player.landed.connect(_hud.show_landing)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _process(_delta: float) -> void:
	var ball := _player.ball
	_best_m = maxf(_best_m, (ball.global_position.x - _start_x) / PIXELS_PER_METER)
	_hud.show_stats(_best_m, ball.linear_velocity.length(), ball is SoftBall)

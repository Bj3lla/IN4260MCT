extends Node2D
## Responsibility: assemble the scene and handle restart / ball swap.
## Everything else lives in its own class: Scenery, Terrain, the players,
## GameCamera and Hud.

const SKY_COLOR := Color("#3a3166")
const PIXELS_PER_METER := 100.0

## Which ball to spawn. Press B to swap; kept across restarts.
static var use_soft_ball := false

var _player: PlayerBase
var _hud: Hud
var _start_x := 0.0
var _best_m := 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(SKY_COLOR)
	
	add_child(StarField.new()) # stars first since they are the furtherest back in thr background
	add_child(Scenery.new())   # Scenery includes all background hills, must be before terrain

	var terrain := Terrain.new()
	add_child(terrain)

	if use_soft_ball:
		_player = SoftPlayer.new()
	else:
		_player = RigidPlayer.new()
	_player.position = Vector2(0.0, terrain.height_at(0.0) - 80.0)
	add_child(_player)
	_start_x = _player.position.x

	var camera := GameCamera.new()
	camera.target = _player
	camera.terrain = terrain
	add_child(camera)

	_hud = Hud.new()
	add_child(_hud)
	_player.landed.connect(_hud.show_landing)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("swap_ball"):
		use_soft_ball = not use_soft_ball
		get_tree().reload_current_scene()


func _process(_delta: float) -> void:
	_best_m = maxf(_best_m, (_player.position.x - _start_x) / PIXELS_PER_METER)
	_hud.show_stats(_best_m, _player.linear_velocity.length(), use_soft_ball)

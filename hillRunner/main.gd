class_name Main
extends Node2D
## Responsibility: assemble the scene and handle restart / ball swap / back to menu.
## Everything else lives in its own class: Scenery, Terrain, the players,
## GameCamera and Hud.

const SKY_COLOR := Color("#3a3166")
const PIXELS_PER_METER := 100.0
const MENU_SCENE := "res://menu.tscn"

enum Ball { RIGID, SOFT, JELLY }
const BALL_NAMES := ["rigid", "soft", "jelly"]

enum Map { CLASSIC, DOWNHILL }
const MAP_NAMES := ["Classic", "Downhill"]
const MAP_TILTS := [0.0, 0.08]   ## px of drop per px forward (0.08 ≈ 4.5°)

## Which ball to spawn. Press B to cycle; kept across restarts.
static var ball_kind := Ball.RIGID
## Which map to play, chosen in the menu.
static var map_kind := Map.CLASSIC

var _player: PlayerBase
var _hud: Hud
var _start_x := 0.0
var _best_m := 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(SKY_COLOR)
	
	add_child(StarField.new()) # stars first since they are the furtherest back in thr background
	var tilt: float = MAP_TILTS[map_kind]
	var scenery := Scenery.new()
	scenery.tilt = tilt
	add_child(scenery)   # Scenery includes all background hills, must be before terrain

	var terrain := Terrain.new()
	terrain.tilt = tilt
	add_child(terrain)

	match ball_kind:
		Ball.SOFT:
			_player = SoftPlayer.new()
		Ball.JELLY:
			_player = JellyPlayer.new()   # rigid movement, soft-ball look
		_:
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
	if event.is_action_pressed("menu"):
		get_tree().change_scene_to_file(MENU_SCENE)
	elif event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("swap_ball"):
		ball_kind = ((ball_kind + 1) % Ball.size()) as Ball
		get_tree().reload_current_scene()


func _process(_delta: float) -> void:
	_best_m = maxf(_best_m, (_player.position.x - _start_x) / PIXELS_PER_METER)
	_hud.show_stats(_best_m, _player.linear_velocity.length(), BALL_NAMES[ball_kind])

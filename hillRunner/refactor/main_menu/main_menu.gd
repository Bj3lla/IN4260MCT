class_name MainMenu
extends Node2D
## Title screen: pick a ball and a mode, then start main.tscn.
## Left/Right: ball, Tab: mode, Enter: play. The world drifts by in the background.

const GAME_SCENE := "res://main.tscn"
const PAN_SPEED := 60.0   ## px/s the background drifts

@onready var _camera: Camera2D = $Camera
@onready var _rigid: Button = %Rigid
@onready var _soft: Button = %Soft
@onready var _free: Button = %FreePlay
@onready var _timed: Button = %Timed


func _ready() -> void:
	RenderingServer.set_default_clear_color(Main.SKY_COLOR)
	(_soft if Player.use_soft_ball else _rigid).button_pressed = true #keeps the last choice
	(_timed if Main.timed else _free).button_pressed = true
	%Play.pressed.connect(_start)


func _process(delta: float) -> void:
	_camera.position.x += PAN_SPEED * delta


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		(_rigid if _soft.button_pressed else _soft).button_pressed = true
	elif event.is_action_pressed("ui_focus_next"): #Tab
		(_free if _timed.button_pressed else _timed).button_pressed = true
	elif event.is_action_pressed("ui_accept"):
		_start()


func _start() -> void:
	Player.use_soft_ball = _soft.button_pressed
	Main.timed = _timed.button_pressed
	get_tree().change_scene_to_file(GAME_SCENE)

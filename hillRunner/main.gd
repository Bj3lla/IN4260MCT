extends Node2D
## Builds the scene in code: sky, terrain, ball, camera and HUD.

const Terrain := preload("res://terrain.gd")
const Ball := preload("res://ball.gd")
const SoftPlayer := preload("res://soft_player.gd")

## Which player to spawn. Press B in game to swap (kept across restarts).
static var use_soft_ball := false

var terrain: Terrain
var ball  ## Ball (rigid) or SoftPlayer (squishy); both have position, linear_velocity and landed
var cam: Camera2D
var hud: Label
var dive_bar: ProgressBar
var landing_label: Label
var landing_timer := 0.0
var start_x := 0.0
var best := 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#6fa8d6"))

	terrain = Terrain.new()
	add_child(terrain)

	ball = SoftPlayer.new() if use_soft_ball else Ball.new()
	ball.position = Vector2(0, terrain.height_at(0) - 80)
	add_child(ball)
	start_x = ball.position.x

	cam = Camera2D.new()
	cam.position = ball.position
	cam.zoom = Vector2(0.7, 0.7)
	add_child(cam)
	cam.make_current()
	terrain.update_view(cam.position.x)

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(20, 16)
	hud.add_theme_font_size_override("font_size", 22)
	hud.add_theme_color_override("font_color", Color("#1d2b45"))
	layer.add_child(hud)
	dive_bar = ProgressBar.new()
	dive_bar.position = Vector2(20, 130)
	dive_bar.size = Vector2(240, 22)
	dive_bar.max_value = 1.0
	dive_bar.show_percentage = false
	layer.add_child(dive_bar)

	landing_label = Label.new()
	landing_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	landing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	landing_label.position.y = 60
	landing_label.add_theme_font_size_override("font_size", 34)
	layer.add_child(landing_label)
	ball.landed.connect(_on_landed)


func _on_landed(kind: String, change: float) -> void:
	var texts := {"great": "Great landing!", "good": "Nice landing", "bad": "Ouch, uphill", "flat": ""}
	if texts[kind] == "":
		return
	landing_label.text = "%s  %+d%%" % [texts[kind], roundi(change * 100)]
	var col := Color("#2e9e5b") if change >= 0 else Color("#d0453d")
	landing_label.add_theme_color_override("font_color", col)
	landing_label.modulate.a = 1.0
	landing_timer = 1.2


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if Input.is_action_just_pressed("swap_ball"):
		use_soft_ball = not use_soft_ball
		get_tree().reload_current_scene()
		return

	# Camera: lead the ball horizontally, zoom out the higher it flies.
	var height: float = terrain.base_y - ball.position.y
	var target_zoom := clampf(0.85 - height / 3000.0, 0.22, 0.85)
	var z := lerpf(cam.zoom.x, target_zoom, 1.0 - exp(-3.0 * delta))
	cam.zoom = Vector2(z, z)
	var target := Vector2(ball.position.x + 250.0 / z, lerpf(ball.position.y, terrain.base_y, 0.4))
	cam.position = cam.position.lerp(target, 1.0 - exp(-8.0 * delta))
	terrain.update_view(cam.position.x)

	var dist: float = (ball.position.x - start_x) / 100.0
	best = maxf(best, dist)
	var dev := "device connected" if AccelInput.connected else "no device (hold SPACE)"
	if AccelInput.is_calibrating():
		dev = "calibrating... hold still"
	hud.text = "Distance: %d m\nSpeed: %d\nInput: %s\n[C] calibrate   [R] restart   [B] ball: %s" % [
		int(best), int(ball.linear_velocity.length()), dev, "soft" if use_soft_ball else "rigid"]
	dive_bar.value = AccelInput.dive
	landing_timer -= delta
	landing_label.modulate.a = clampf(landing_timer / 0.4, 0.0, 1.0)

extends Node2D
## Responsibility: the title screen. Shows the night sky and drifting hills
## from the game behind a ball, map and mode picker, then starts main.tscn
## with the choices (stored in Main.ball_kind / map_kind / timed, kept across
## restarts). The background previews the chosen map's tilt, and the session
## leaderboard shows on the right once someone has played a timed run.
##
## Controls: Left/Right (or A/D, 1-3, mouse hover) to choose a ball,
## Up/Down (or W/S, click) to choose a map, Tab (or click) to choose a mode,
## Enter/Space or click to play.

const GAME_SCENE := "res://main.tscn"
const SKY_COLOR := UiStyle.SKY
const TEXT_COLOR := UiStyle.TEXT
const ACCENT := UiStyle.ACCENT
const MOON: Texture2D = preload("res://visuals/Moon.svg")
const SPARKLES: Array[Texture2D] = [
	preload("res://visuals/Sparkle white.svg"),
	preload("res://visuals/Sparkle pink.svg"),
	preload("res://visuals/Sparkle blue.svg"),
]
const PAN_SPEED := 60.0   ## px/s the background drifts
const MODE_NAMES := ["Free play", "1 minute"]
const LEADERBOARD_ROWS := 5

const BALLS := [
	{ "kind": Main.Ball.RIGID, "name": "Rigid", "lines": ["Hard and quick.", "Slides like ice."] },
	{ "kind": Main.Ball.SOFT, "name": "Soft", "lines": ["A squishy soft body.", "Blushes when diving."] },
	{ "kind": Main.Ball.JELLY, "name": "Jelly", "lines": ["Soft look,", "rigid moves."] },
]

var _cards: Array[BallCard] = []
var _selected := 0
var _map := -1
var _map_row: HBoxContainer
var _mode_row: HBoxContainer
var _timed := false
var _scenery: Scenery
var _camera: Camera2D
var _sparkles: Array[Sprite2D] = []
var _time := 0.0
var _starting := false


func _ready() -> void:
	RenderingServer.set_default_clear_color(SKY_COLOR)
	add_child(StarField.new())

	_camera = Camera2D.new()
	_camera.position = Vector2(0.0, Scenery.REFERENCE_CAMERA_Y)
	_camera.zoom = Vector2.ONE * Scenery.REFERENCE_ZOOM
	add_child(_camera)
	_camera.make_current()

	var ui := CanvasLayer.new()
	add_child(ui)
	_build_sky_decor(ui)
	_build_ui(ui)
	_build_leaderboard(ui)

	_selected = BALLS.map(func(b): return b.kind).find(Main.ball_kind)
	_select(maxi(_selected, 0))
	_select_map(Main.map_kind)
	_select_mode(1 if Main.timed else 0)


func _process(delta: float) -> void:
	_time += delta
	_camera.position.x += PAN_SPEED * delta
	# Follow the map's slope so a tilted map keeps drifting downhill.
	_camera.position.y = Scenery.REFERENCE_CAMERA_Y + _camera.position.x * _tilt()
	for i in _sparkles.size():
		var s := _sparkles[i]
		var twinkle := 0.5 + 0.5 * sin(_time * 2.0 + i * 1.7)
		s.modulate.a = lerpf(0.25, 1.0, twinkle)
		s.scale = Vector2.ONE * lerpf(0.8, 1.15, twinkle)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") or _is_key(event, KEY_A):
		_select(posmod(_selected - 1, BALLS.size()))
	elif event.is_action_pressed("ui_right") or _is_key(event, KEY_D):
		_select((_selected + 1) % BALLS.size())
	elif (event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down")
			or _is_key(event, KEY_W) or _is_key(event, KEY_S)):
		_select_map((_map + 1) % Main.MAP_NAMES.size())
	elif _is_key(event, KEY_TAB):
		_select_mode(0 if _timed else 1)
	elif event.is_action_pressed("ui_accept"):
		_start()
	elif event is InputEventKey and event.pressed and not event.echo:
		var n: int = event.physical_keycode - KEY_1
		if n >= 0 and n < BALLS.size():
			_select(n)


func _is_key(event: InputEvent, key: Key) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == key


func _select(index: int) -> void:
	_selected = index
	for i in _cards.size():
		_cards[i].selected = i == index


func _select_map(index: int) -> void:
	UiStyle.set_toggle_row(_map_row, index)
	if index == _map:
		return
	_map = index
	# Rebuild the background hills with this map's tilt (right after the stars).
	if _scenery:
		_scenery.queue_free()
	_scenery = Scenery.new()
	_scenery.tilt = _tilt()
	add_child(_scenery)
	move_child(_scenery, 1)


func _select_mode(index: int) -> void:
	_timed = index == 1
	UiStyle.set_toggle_row(_mode_row, index)


func _tilt() -> float:
	return Main.MAP_TILTS[maxi(_map, 0)]


func _start() -> void:
	if _starting:
		return
	_starting = true
	Main.ball_kind = BALLS[_selected].kind
	Main.map_kind = _map as Main.Map
	Main.timed = _timed
	get_tree().change_scene_to_file(GAME_SCENE)


# --- construction ------------------------------------------------------------

func _build_sky_decor(ui: CanvasLayer) -> void:
	var moon := Sprite2D.new()
	moon.texture = MOON
	moon.position = Vector2(1110, 120)
	ui.add_child(moon)

	var spots := [Vector2(370, 95), Vector2(905, 80), Vector2(330, 205), Vector2(950, 200), Vector2(640, 40)]
	for i in spots.size():
		var s := Sprite2D.new()
		s.texture = SPARKLES[i % SPARKLES.size()]
		s.position = spots[i]
		ui.add_child(s)
		_sparkles.append(s)


func _build_ui(ui: CanvasLayer) -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 14)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	root.add_child(UiStyle.label("Hill Ball", 96, TEXT_COLOR, 14))
	root.add_child(UiStyle.label("Choose your ball", 26, TEXT_COLOR.darkened(0.15), 6))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	root.add_child(row)
	for i in BALLS.size():
		var card := BallCard.new()
		card.info = BALLS[i]
		card.hovered.connect(_select.bind(i))
		card.clicked.connect(_start)
		row.add_child(card)
		_cards.append(card)

	var options := HBoxContainer.new()
	options.alignment = BoxContainer.ALIGNMENT_CENTER
	options.add_theme_constant_override("separation", 40)
	root.add_child(options)
	_map_row = UiStyle.toggle_row("Map", Main.MAP_NAMES, _select_map)
	options.add_child(_map_row)
	_mode_row = UiStyle.toggle_row("Mode", MODE_NAMES, _select_mode)
	options.add_child(_mode_row)

	var play := UiStyle.button("Play")
	play.pressed.connect(_start)
	root.add_child(play)

	root.add_child(UiStyle.label(
			"Left / Right: ball   ·   Up / Down: map   ·   Tab: mode   ·   Enter: play   ·   Esc in game returns here",
			18, SKY_COLOR))


## Session leaderboard, top right under the moon. Only shown after a timed run.
func _build_leaderboard(ui: CanvasLayer) -> void:
	if Leaderboard.entries.is_empty():
		return
	var panel := PanelContainer.new()
	var style := UiStyle.panel()
	style.bg_color.a = 0.7
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	ui.add_child(panel)

	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(UiStyle.label("Leaderboard", 22, ACCENT))
	box.add_child(Results.table(LEADERBOARD_ROWS, -1, 16, false))

	# Anchor to the right edge, under the moon.
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_right = -16.0
	panel.offset_top = 196.0


## One choice in the picker: a translucent panel with a live preview of the
## ball (bouncing when selected; soft balls squash and blush) and its name.
class BallCard extends Control:
	signal hovered
	signal clicked

	const SIZE := Vector2(230, 270)
	const BALL_RADIUS := 42.0
	const GROUND_Y := 150.0
	const BOUNCE_HEIGHT := 46.0
	const TEXTURE: Texture2D = preload("res://visuals/Ball character.svg")

	var info: Dictionary
	var selected := false:
		set(value):
			selected = value
			queue_redraw()

	var _time := 0.0
	var _panel := StyleBoxFlat.new()
	var _panel_selected := StyleBoxFlat.new()

	func _ready() -> void:
		custom_minimum_size = SIZE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func(): hovered.emit())
		for box in [_panel, _panel_selected]:
			box.set_corner_radius_all(22)
			box.anti_aliasing = true
		_panel.bg_color = Color(0.1, 0.07, 0.25, 0.45)
		_panel.border_color = Color(1, 1, 1, 0.15)
		_panel.set_border_width_all(2)
		_panel_selected.bg_color = Color(0.1, 0.07, 0.25, 0.7)
		_panel_selected.border_color = ACCENT
		_panel_selected.set_border_width_all(4)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit()

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var box := _panel_selected if selected else _panel
		draw_style_box(box, Rect2(Vector2.ZERO, size))

		var squishy: bool = info.kind != Main.Ball.RIGID
		var cx := size.x * 0.5

		# Bounce only when selected; |sin| gives a hop that hits the ground sharply.
		var hop := absf(sin(_time * 3.2)) if selected else 0.0
		var lift := hop * BOUNCE_HEIGHT
		var squash := 0.0
		if squishy and selected:
			squash = clampf(1.0 - hop / 0.3, 0.0, 1.0) * 0.28
		var squeeze := Vector2(1.0 + squash, 1.0 - squash)

		# Shadow shrinks as the ball rises.
		var shadow_w := BALL_RADIUS * lerpf(1.0, 0.55, hop)
		draw_set_transform(Vector2(cx, GROUND_Y + 4.0), 0.0, Vector2(1.0, 0.25))
		draw_circle(Vector2.ZERO, shadow_w, Color(0, 0, 0, 0.25))

		# Ball, with its bottom resting on the ground line.
		var center := Vector2(cx, GROUND_Y - lift - BALL_RADIUS * squeeze.y)
		draw_set_transform(center, 0.0, squeeze)
		var tint := Color.WHITE
		if squishy:
			var blush := (0.5 + 0.5 * sin(_time * 2.0)) if selected else 0.0
			tint = PlayerBase.dive_color(blush)
		var r := BALL_RADIUS
		draw_texture_rect(TEXTURE, Rect2(-r, -r, r * 2.0, r * 2.0), false, tint)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color.WHITE, 3.0, true)
		draw_set_transform(Vector2.ZERO)

		var font := get_theme_default_font()
		var text_color := TEXT_COLOR if selected else TEXT_COLOR.darkened(0.25)
		draw_string(font, Vector2(0, 200), info.name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 30,
				ACCENT if selected else text_color)
		for i in info.lines.size():
			draw_string(font, Vector2(0, 230 + i * 22), info.lines[i], HORIZONTAL_ALIGNMENT_CENTER,
					size.x, 17, text_color)

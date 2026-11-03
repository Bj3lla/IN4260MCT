extends Node2D
## Responsibility: the title screen. Shows the night sky and drifting hills
## from the game behind a ball and map picker, then starts main.tscn with the
## choices (stored in Main.ball_kind / Main.map_kind, kept across restarts).
## The background previews the chosen map's tilt.
##
## Controls: Left/Right (or A/D, 1-3, mouse hover) to choose a ball,
## Up/Down (or W/S, click) to choose a map, Enter/Space or click to play.

const GAME_SCENE := "res://main.tscn"
const SKY_COLOR := Color("#3a3166")
const TEXT_COLOR := Color("#FFF4D8")
const ACCENT := Color("#FF87B6")
const MOON: Texture2D = preload("res://visuals/Moon.svg")
const SPARKLES: Array[Texture2D] = [
	preload("res://visuals/Sparkle white.svg"),
	preload("res://visuals/Sparkle pink.svg"),
	preload("res://visuals/Sparkle blue.svg"),
]
const PAN_SPEED := 60.0   ## px/s the background drifts

const BALLS := [
	{ "kind": Main.Ball.RIGID, "name": "Rigid", "lines": ["Hard and quick.", "Slides like ice."] },
	{ "kind": Main.Ball.SOFT, "name": "Soft", "lines": ["A squishy soft body.", "Blushes when diving."] },
	{ "kind": Main.Ball.JELLY, "name": "Jelly", "lines": ["Soft look,", "rigid moves."] },
]

var _cards: Array[BallCard] = []
var _selected := 0
var _map := -1
var _map_buttons: Array[Button] = []
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

	_selected = BALLS.map(func(b): return b.kind).find(Main.ball_kind)
	_select(maxi(_selected, 0))
	_select_map(Main.map_kind)


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
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") 			or _is_key(event, KEY_W) or _is_key(event, KEY_S):
		_select_map((_map + 1) % Main.MAP_NAMES.size())
	elif event.is_action_pressed("ui_accept"):
		_start()
	elif event is InputEventKey and event.pressed and not event.echo:
		var n: int = event.physical_keycode - KEY_1
		if n >= 0 and n < BALLS.size():
			_select(n)


func _is_key(event: InputEvent, key: Key) -> bool:
	return event is InputEventKey and event.pressed and event.physical_keycode == key


func _select(index: int) -> void:
	_selected = index
	for i in _cards.size():
		_cards[i].selected = i == index


func _select_map(index: int) -> void:
	for i in _map_buttons.size():
		var on := i == index
		_map_buttons[i].add_theme_stylebox_override("normal", _pill(TEXT_COLOR) if on else _outline_pill())
		_map_buttons[i].add_theme_stylebox_override("hover", _pill(ACCENT) if on else _outline_pill(ACCENT))
		for state in ["font_color", "font_hover_color", "font_pressed_color"]:
			_map_buttons[i].add_theme_color_override(state, SKY_COLOR if on else TEXT_COLOR)
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


func _tilt() -> float:
	return Main.MAP_TILTS[maxi(_map, 0)]


func _start() -> void:
	if _starting:
		return
	_starting = true
	Main.ball_kind = BALLS[_selected].kind
	Main.map_kind = _map as Main.Map
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

	root.add_child(_label("Hill Ball", 96, TEXT_COLOR, 14))
	root.add_child(_label("Choose your ball", 26, TEXT_COLOR.darkened(0.15), 6))

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

	var maps := HBoxContainer.new()
	maps.alignment = BoxContainer.ALIGNMENT_CENTER
	maps.add_theme_constant_override("separation", 12)
	root.add_child(maps)
	var map_label := _label("Map", 22, TEXT_COLOR, 6)
	map_label.custom_minimum_size.x = 60
	maps.add_child(map_label)
	for i in Main.MAP_NAMES.size():
		var b := Button.new()
		b.text = Main.MAP_NAMES[i]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(150, 40)
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_stylebox_override("pressed", _pill(ACCENT.darkened(0.15)))
		b.pressed.connect(_select_map.bind(i))
		maps.add_child(b)
		_map_buttons.append(b)

	var play := Button.new()
	play.text = "Play"
	play.focus_mode = Control.FOCUS_NONE
	play.custom_minimum_size = Vector2(220, 64)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.add_theme_font_size_override("font_size", 32)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		play.add_theme_color_override(state, SKY_COLOR)
	play.add_theme_stylebox_override("normal", _pill(TEXT_COLOR))
	play.add_theme_stylebox_override("hover", _pill(ACCENT))
	play.add_theme_stylebox_override("pressed", _pill(ACCENT.darkened(0.15)))
	play.pressed.connect(_start)
	root.add_child(play)

	root.add_child(_label("Left / Right: ball   ·   Up / Down: map   ·   Enter: play   ·   Esc in game returns here",
			18, SKY_COLOR, 0))


func _label(text: String, size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", SKY_COLOR.darkened(0.3))
	l.add_theme_constant_override("outline_size", outline)
	return l


## Hollow pill for unselected options.
func _outline_pill(border := TEXT_COLOR) -> StyleBoxFlat:
	var box := _pill(Color(0.1, 0.07, 0.25, 0.45))
	box.border_color = border
	box.set_border_width_all(2)
	return box


func _pill(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(32)
	box.anti_aliasing = true
	return box


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

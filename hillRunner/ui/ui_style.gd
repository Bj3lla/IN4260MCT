class_name UiStyle
## Responsibility: the shared look of menus and overlays: colours, labels and
## pill-shaped buttons, so the title screen and results screen match.

const SKY := Color("#3a3166")
const TEXT := Color("#FFF4D8")
const ACCENT := Color("#FF87B6")
const PANEL := Color(0.1, 0.07, 0.25, 0.45)


static func label(text: String, size: int, color := TEXT, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", SKY.darkened(0.3))
	l.add_theme_constant_override("outline_size", outline)
	return l


static func pill(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(32)
	box.anti_aliasing = true
	return box


## Hollow pill for unselected options.
static func outline_pill(border := TEXT) -> StyleBoxFlat:
	var box := pill(PANEL)
	box.border_color = border
	box.set_border_width_all(2)
	return box


## Rounded translucent panel, with a pink border when highlighted.
static func panel(highlight := false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.07, 0.25, 0.7 if highlight else 0.45)
	box.border_color = ACCENT if highlight else Color(1, 1, 1, 0.15)
	box.set_border_width_all(4 if highlight else 2)
	box.set_corner_radius_all(22)
	box.anti_aliasing = true
	return box


## Big cream button that turns pink on hover (Play, Play again, ...).
static func button(text: String, width := 220.0, font_size := 32) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(width, font_size * 2)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(state, SKY)
	b.add_theme_stylebox_override("normal", pill(TEXT))
	b.add_theme_stylebox_override("hover", pill(ACCENT))
	b.add_theme_stylebox_override("pressed", pill(ACCENT.darkened(0.15)))
	return b


## Row of pill toggles; the selected one is filled. Restyle with set_toggle_row.
static func toggle_row(title: String, options: Array, on_pick: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var l := label(title, 22, TEXT, 6)
	l.custom_minimum_size.x = 70
	row.add_child(l)
	for i in options.size():
		var b := Button.new()
		b.text = options[i]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(140, 40)
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_stylebox_override("pressed", pill(ACCENT.darkened(0.15)))
		b.pressed.connect(on_pick.bind(i))
		row.add_child(b)
	return row


static func set_toggle_row(row: HBoxContainer, selected: int) -> void:
	for i in row.get_child_count() - 1:
		var b := row.get_child(i + 1) as Button
		var on := i == selected
		b.add_theme_stylebox_override("normal", pill(TEXT) if on else outline_pill())
		b.add_theme_stylebox_override("hover", pill(ACCENT) if on else outline_pill(ACCENT))
		for state in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(state, SKY if on else TEXT)

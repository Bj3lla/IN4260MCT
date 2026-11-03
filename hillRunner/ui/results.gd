class_name Results
extends CanvasLayer
## Responsibility: the "time's up" screen of timed mode. Pauses the game,
## shows the distance, asks for a name, adds the score to the Leaderboard and
## shows the table. Then R plays again and Esc goes back to the menu.
## Set the fields below before add_child().

signal play_again
signal to_menu

const SHOWN_ROWS := 8

var meters := 0.0
var ball_name := ""
var map_name := ""

var _box: VBoxContainer
var _name_row: HBoxContainer
var _name_edit: LineEdit
var _hint: Label
var _title: Label
var _table_holder: Control
var _after: Control
var _saved := false


## Score table: rank, name, metres and (if `details`) ball / map.
## `highlight` is a row index to colour pink.
static func table(limit: int, highlight := -1, font_size := 20, details := true) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4 if details else 3
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 4)
	var rows := range(mini(limit, Leaderboard.entries.size()))
	if highlight >= limit:
		rows.append(highlight)   # always show the player's own row
	for i in rows:
		var e: Dictionary = Leaderboard.entries[i]
		var color := UiStyle.ACCENT if i == highlight else UiStyle.TEXT
		var cells := ["%d." % (i + 1), e.name, "%d m" % e.meters]
		if details:
			cells.append("%s · %s" % [e.ball, e.map])
		for c in cells.size():
			var l := UiStyle.label(cells[c], font_size, color)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if c in [0, 2] else HORIZONTAL_ALIGNMENT_LEFT
			if c == 3:
				l.modulate.a = 0.7
			grid.add_child(l)
	return grid


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	var dim := ColorRect.new()
	dim.color = Color(UiStyle.SKY.darkened(0.4), 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var style := UiStyle.panel(true)
	style.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	panel.add_child(_box)

	_title = UiStyle.label("Time's up!", 48, UiStyle.TEXT, 8)
	_box.add_child(_title)
	_box.add_child(UiStyle.label("%d m" % int(meters), 80, UiStyle.ACCENT, 10))
	_box.add_child(UiStyle.label("%s ball · %s" % [ball_name.capitalize(), map_name], 20,
			UiStyle.TEXT.darkened(0.2)))

	# Name entry, replaced by the table once saved.
	_name_row = HBoxContainer.new()
	_name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_name_row.add_theme_constant_override("separation", 12)
	_box.add_child(_name_row)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = Leaderboard.default_name()
	_name_edit.max_length = 14
	_name_edit.custom_minimum_size = Vector2(260, 48)
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.add_theme_font_size_override("font_size", 24)
	_name_edit.add_theme_color_override("font_color", UiStyle.SKY)
	_name_edit.add_theme_color_override("font_placeholder_color", UiStyle.SKY.lightened(0.4))
	_name_edit.add_theme_color_override("caret_color", UiStyle.SKY)
	for state in ["normal", "focus"]:
		var box := UiStyle.pill(UiStyle.TEXT)
		box.set_content_margin_all(8)
		_name_edit.add_theme_stylebox_override(state, box)
	_name_edit.text_submitted.connect(func(_t): _save())
	_name_row.add_child(_name_edit)
	var save := UiStyle.button("Save", 130, 24)
	save.pressed.connect(_save)
	_name_row.add_child(save)
	_hint = UiStyle.label("Type your name and press Enter", 16, UiStyle.TEXT.darkened(0.3))
	_box.add_child(_hint)

	_table_holder = CenterContainer.new()
	_box.add_child(_table_holder)

	_after = HBoxContainer.new()
	_after.alignment = BoxContainer.ALIGNMENT_CENTER
	_after.add_theme_constant_override("separation", 16)
	_after.visible = false
	_box.add_child(_after)
	var again := UiStyle.button("Play again", 200, 24)
	again.pressed.connect(_leave.bind(true))
	_after.add_child(again)
	var menu := UiStyle.button("Menu", 140, 24)
	menu.pressed.connect(_leave.bind(false))
	_after.add_child(menu)

	_name_edit.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not _saved:
		return
	if event.is_action_pressed("restart") or event.is_action_pressed("ui_accept"):
		_leave(true)
	elif event.is_action_pressed("menu"):
		_leave(false)


func _save() -> void:
	if _saved:
		return
	_saved = true
	var rank := Leaderboard.add(_name_edit.text, meters, ball_name, map_name)
	_hint.queue_free()
	_name_row.queue_free()
	_title.text = "You placed #%d!" % (rank + 1)
	_table_holder.add_child(table(SHOWN_ROWS, rank))
	_after.visible = true


func _leave(again: bool) -> void:
	get_tree().paused = false
	if again:
		play_again.emit()
	else:
		to_menu.emit()

class_name Hud
extends CanvasLayer
## On-screen text and the dive bar. Display only: it is told
## the stats and landing events, and reads the dive value from InputProcessing.

const TEXT_COLOR := Color("#FFF4D8")
const GOOD_COLOR := Color("#7fe0a0")
const BAD_COLOR := Color("#ff8a80")
const LANDING_TEXTS := {"great": "Great landing!", "good": "Nice landing", "bad": "Ouch, uphill"}
const SHOW_TIME := 1.2
const FADE_TIME := 0.4

var _stats: Label
var _distance: Label
var _dive_bar: ProgressBar
var _rotate_bar: ProgressBar    #from boost-motion branch
var _landing: Label
var _landing_timer := 0.0
var _result: Label


func _ready() -> void:
	_stats = Label.new()
	_stats.position = Vector2(20, 16)
	_stats.add_theme_font_size_override("font_size", 22)
	_stats.add_theme_color_override("font_color", TEXT_COLOR)
	add_child(_stats)

	# Anchored to the bottom-right corner, grows left and up as the text gets longer.
	_distance = Label.new()
	_distance.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_distance.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_distance.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_distance.offset_right = -24.0
	_distance.offset_bottom = -16.0
	_distance.add_theme_font_size_override("font_size", 56)
	_distance.add_theme_color_override("font_color", TEXT_COLOR)
	add_child(_distance)

	_dive_bar = ProgressBar.new()
	_dive_bar.position = Vector2(20, 130)
	_dive_bar.size = Vector2(240, 22)
	_dive_bar.min_value = -1.0
	_dive_bar.max_value = 1.0
	_dive_bar.show_percentage = false
	add_child(_dive_bar)
	
	 # from boost-motion branch
	_rotate_bar = ProgressBar.new()
	_rotate_bar.position = Vector2(20, 100)
	_rotate_bar.size = Vector2(240, 22)
	_rotate_bar.max_value = 1.0
	_rotate_bar.show_percentage = false
	add_child(_rotate_bar)

	# Anchored across the top, text centred, so it is centred regardless of tree timing.
	_landing = Label.new()
	_landing.anchor_right = 1.0
	_landing.offset_top = 60.0
	_landing.offset_bottom = 110.0
	_landing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_landing.add_theme_font_size_override("font_size", 34)
	_landing.modulate.a = 0.0
	add_child(_landing)

	# Fills the screen, text centred. Shown when a timed run ends.
	_result = Label.new()
	_result.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result.add_theme_font_size_override("font_size", 48)
	_result.add_theme_color_override("font_color", TEXT_COLOR)
	_result.hide()
	add_child(_result)


func _process(delta: float) -> void:
	_dive_bar.value = InputProcessing.dive
	_rotate_bar.value = InputProcessing.rotation
	_landing_timer -= delta
	_landing.modulate.a = clampf(_landing_timer / FADE_TIME, 0.0, 1.0)


## time_left is only shown in timed mode (pass -1 otherwise).
func show_stats(distance_m: float, speed: float, soft_ball: bool, time_left := -1.0) -> void:
	var device := "device connected" if InputProcessing.connected else "no device (hold SPACE / mouse)"
	if InputProcessing.is_calibrating():
		device = "calibrating... hold still"
	var time := ("Time: %d s\n" % ceili(time_left)) if time_left >= 0.0 else ""
	_stats.text = "%sSpeed: %d\nInput: %s\n[C] calibrate   [R] restart   [B] ball: %s   [Esc] menu" % [
		time, int(speed), device, "soft" if soft_ball else "rigid"]
	_distance.text = "%d m" % int(distance_m)


func show_result(distance_m: float) -> void:
	_result.text = "Time's up!\nYou got %d m\n\n[R] play again   [Esc] menu" % int(distance_m)
	_result.show()


## Connect to a player's `landed` signal.
func show_landing(kind: String, change: float) -> void:
	if not LANDING_TEXTS.has(kind):
		return
	_landing.text = "%s  %+d%%" % [LANDING_TEXTS[kind], roundi(change * 100.0)]
	_landing.add_theme_color_override("font_color", GOOD_COLOR if change >= 0.0 else BAD_COLOR)
	_landing_timer = SHOW_TIME

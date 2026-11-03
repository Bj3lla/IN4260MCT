class_name Hud
extends CanvasLayer
## Responsibility: on-screen text and the dive bar. Display only: it is told
## the stats and landing events, and reads the dive value from AccelInput.

const TEXT_COLOR := Color("#FFF4D8")
const GOOD_COLOR := Color("#7fe0a0")
const BAD_COLOR := Color("#ff8a80")
const LANDING_TEXTS := {"great": "Great landing!", "good": "Nice landing", "bad": "Ouch, uphill"}
const SHOW_TIME := 1.2
const FADE_TIME := 0.4

var _stats: Label
var _dive_bar: ProgressBar
var _landing: Label
var _landing_timer := 0.0
var _clock: Label
var _distance: Label


func _ready() -> void:
	_stats = Label.new()
	_stats.position = Vector2(20, 16)
	_stats.add_theme_font_size_override("font_size", 22)
	_stats.add_theme_color_override("font_color", TEXT_COLOR)
	add_child(_stats)

	_dive_bar = ProgressBar.new()
	_dive_bar.position = Vector2(20, 130)
	_dive_bar.size = Vector2(240, 22)
	_dive_bar.max_value = 1.0
	_dive_bar.show_percentage = false
	add_child(_dive_bar)

	# Anchored across the top, text centred, so it is centred regardless of tree timing.
	_landing = Label.new()
	_landing.anchor_right = 1.0
	_landing.offset_top = 66.0
	_landing.offset_bottom = 116.0
	_landing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_landing.add_theme_font_size_override("font_size", 34)
	_landing.modulate.a = 0.0
	add_child(_landing)

	# Timed-mode countdown, top centre. Hidden until show_timer is called.
	_clock = Label.new()
	_clock.anchor_right = 1.0
	_clock.offset_top = 8.0
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.add_theme_font_size_override("font_size", 44)
	_clock.add_theme_color_override("font_outline_color", Color("#3a3166").darkened(0.3))
	_clock.add_theme_constant_override("outline_size", 8)
	_clock.visible = false
	add_child(_clock)

	# Distance, bottom-right corner. Outlined so it reads on the light hills.
	_distance = Label.new()
	_distance.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_distance.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_distance.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_distance.offset_right = -24.0
	_distance.offset_bottom = -12.0
	_distance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_distance.add_theme_font_size_override("font_size", 44)
	_distance.add_theme_color_override("font_color", TEXT_COLOR)
	_distance.add_theme_color_override("font_outline_color", Color("#3a3166").darkened(0.3))
	_distance.add_theme_constant_override("outline_size", 8)
	add_child(_distance)


func _process(delta: float) -> void:
	_dive_bar.value = AccelInput.dive
	_landing_timer -= delta
	_landing.modulate.a = clampf(_landing_timer / FADE_TIME, 0.0, 1.0)


func show_stats(distance_m: float, speed: float, ball_name: String) -> void:
	var device := "device connected" if AccelInput.connected else "no device (hold SPACE / mouse)"
	if AccelInput.is_calibrating():
		device = "calibrating... hold still"
	_distance.text = "%d m" % int(distance_m)
	_stats.text = "Speed: %d\nInput: %s\n[C] calibrate   [R] restart   [B] ball: %s   [Esc] menu" % [
		int(speed), device, ball_name]


## Timed mode: seconds left. Turns pink for the last 10 seconds.
func show_timer(seconds_left: float) -> void:
	var s := ceili(seconds_left)
	_clock.visible = true
	_clock.text = "%d:%02d" % [s / 60, s % 60]
	_clock.add_theme_color_override("font_color", Color("#FF87B6") if seconds_left <= 10.0 else TEXT_COLOR)


## Connect to a player's `landed` signal.
func show_landing(kind: String, change: float) -> void:
	if not LANDING_TEXTS.has(kind):
		return
	_landing.text = "%s  %+d%%" % [LANDING_TEXTS[kind], roundi(change * 100.0)]
	_landing.add_theme_color_override("font_color", GOOD_COLOR if change >= 0.0 else BAD_COLOR)
	_landing_timer = SHOW_TIME

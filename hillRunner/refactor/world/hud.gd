class_name Hud
extends CanvasLayer
## On-screen text and the dive bar. Display only: it is told
## the stats and landing events, and reads the dive value from InputProcessing.

const TEXT_COLOR := Color("#EDE3C9")
const OUTLINE_COLOR := Color("#231C45")
const GOOD_COLOR := Color("#60F4EA")
const BAD_COLOR := Color("#FF5C7A")
const GOLD_COLOR := Color("#FFD166")
const BOOST_COLOR := Color("#FF6BDD")
const MARGIN := 20
const LANDING_TEXTS := {"great": "Great landing!", "good": "Nice landing", "bad": "Ouch, uphill"}
const SHOW_TIME := 1.2
const FADE_TIME := 0.4
const MAX_SPEED := 2000.0  # speed that fills the speedometer
const BOOST_DRAIN := 0.1 # per second

var _stats: Label
var _distance: Label
var _dive_bar: ProgressBar
var _rotate_bar: ProgressBar    #from boost-motion branch
var _boost_bar: ProgressBar
var _landing: Label
var _landing_change: Label
var _landing_box: VBoxContainer
var _landing_timer := 0.0
var _use_boost := false #this one needs to be updated from the boost method!


func _ready() -> void:
	_stats = _make_label(14, self)
	_stats.position = Vector2(240, 240)

	_distance = _make_label(34, self)
	_distance.size = Vector2(240, 50)
	_distance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT 
	_distance.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, MARGIN)
	
	_boost_bar = _make_bar(GOLD_COLOR, Vector2(240, 44))
	_boost_bar.value = 1.0 #starts from full
	_boost_bar.position = Vector2(20, 660)
	
	_dive_bar = _make_bar(GOOD_COLOR, Vector2(22, 200))
	_dive_bar.min_value = -1.0
	_dive_bar.position = Vector2(20, 20)
	_dive_bar.fill_mode = ProgressBar.FILL_TOP_TO_BOTTOM
	
	 # from boost-motion branch
	_rotate_bar = _make_bar(GOLD_COLOR, Vector2(240, 22))
	_rotate_bar.min_value = -1.0
	_rotate_bar.position = Vector2(20, 620)
	
	_landing_box = VBoxContainer.new()
	_landing_box.anchor_right = 1.0
	_landing_box.offset_top = 40
	_landing_box.modulate.a = 0.0
	add_child(_landing_box)
	
	_landing = _make_label(34, _landing_box)
	_landing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_landing_change = _make_label(20, _landing_box)
	_landing_change.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _process(delta: float) -> void:
	if _use_boost:
		_boost_bar.value -= BOOST_DRAIN * delta #empties boost-bar whenever boost is used 
		
	_dive_bar.value = InputProcessing.dive
	_rotate_bar.value = InputProcessing.rotation
	_landing_timer -= delta
	_landing_box.modulate.a = clampf(_landing_timer / FADE_TIME, 0.0, 1.0)


func show_stats(distance_m: float, speed: float, soft_ball: bool) -> void:
	var device := "device connected" if InputProcessing.connected else "no device (hold SPACE / mouse)"
	if InputProcessing.is_calibrating():
		device = "calibrating... hold still"
	_distance.text =  "%d m" % int(distance_m)


## Connect to a player's `landed` signal.
func show_landing(kind: String, change: float) -> void:
	if not LANDING_TEXTS.has(kind):
		return
	_landing.text = LANDING_TEXTS[kind]
	_landing.add_theme_color_override("font_color", GOOD_COLOR if change >= 0.0 else BAD_COLOR)
	_landing_change.text = "%+d%% speed" % roundi(change * 100.0)
	_landing_timer = SHOW_TIME
	
	
func _make_label(font_size: int, parent: Node) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", 6)
	parent.add_child(label)
	return label
	
	
func _make_bar(color: Color, bar_size: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.size = bar_size
	bar.max_value = 1.0
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = OUTLINE_COLOR
	background.set_corner_radius_all(8)
	var fill: StyleBoxFlat = background.duplicate()
	fill.bg_color = color
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	add_child(bar)
	return bar

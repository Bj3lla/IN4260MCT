extends Node
## Autoload "AccelInput". Responsibility: turn input devices into one 0..1
## `dive` value. Reads accelerometer samples over UDP; Space / left mouse
## button work as a fallback.
##
## Packet formats (one sample per packet, UTF-8 text):
##   "0.12,-0.40,9.81"              comma / space / semicolon separated x,y,z
##   {"x":0.12,"y":-0.40,"z":9.81}  JSON
## Units don't matter as long as threshold / full_scale match.

signal sample_received(accel: Vector3)

@export var port := 4242
## Which device axis counts as "pushing down". Flip the sign if it feels inverted.
@export var axis := Vector3(0, 0, 1)
## Use the total change in acceleration instead of a single axis.
@export var use_magnitude := false
## Change (relative to the calibrated rest value) needed before diving starts.
@export var threshold := 1.0
## Change that counts as a full dive.
@export var full_scale := 5.0
## Higher = snappier, lower = smoother.
@export var smoothing := 15.0
## Seconds without packets before the device counts as disconnected.
@export var timeout := 0.5
@export var calibration_samples := 30

var raw := Vector3.ZERO
var baseline := Vector3.ZERO
var dive := 0.0            ## final smoothed value, 0..1
var device_dive := 0.0     ## unsmoothed value from the device only
var connected := false

var _udp := PacketPeerUDP.new()
var _last_packet_s := -1000.0
var _cal_left := 0
var _cal_sum := Vector3.ZERO
var _cal_n := 0


func _ready() -> void:
	_ensure_default_actions()
	calibrate()   # auto-calibrate on the first samples
	var err := _udp.bind(port)
	if err != OK:
		push_error("AccelInput: could not bind UDP port %d (error %d)" % [port, err])
	else:
		print("AccelInput: listening on UDP port %d" % port)


## Hold the device still in its neutral pose while this runs.
func calibrate() -> void:
	_cal_left = calibration_samples
	_cal_sum = Vector3.ZERO
	_cal_n = 0


## Only true while a device is actually streaming samples.
func is_calibrating() -> bool:
	return connected and _cal_left > 0


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0

	while _udp.get_available_packet_count() > 0:
		var parsed = _parse(_udp.get_packet().get_string_from_utf8())
		if parsed != null:
			_on_sample(parsed)
			_last_packet_s = now

	connected = now - _last_packet_s < timeout
	if not connected:
		device_dive = 0.0

	if Input.is_action_just_pressed("calibrate"):
		calibrate()

	var target := 1.0 if Input.is_action_pressed("dive") else device_dive
	dive = lerpf(dive, target, 1.0 - exp(-smoothing * delta))


func _on_sample(a: Vector3) -> void:
	raw = a
	sample_received.emit(a)

	if _cal_left > 0:
		_cal_sum += a
		_cal_n += 1
		_cal_left -= 1
		baseline = _cal_sum / _cal_n
		device_dive = 0.0
		return

	var d := a - baseline
	var v := d.length() if use_magnitude else d.dot(axis.normalized())
	device_dive = clampf((v - threshold) / maxf(full_scale - threshold, 0.001), 0.0, 1.0)


func _parse(text: String) -> Variant:
	text = text.strip_edges()
	if text.is_empty():
		return null
	if text.begins_with("{"):
		var j = JSON.parse_string(text)
		if typeof(j) == TYPE_DICTIONARY and j.has("x") and j.has("y") and j.has("z"):
			return Vector3(float(j.x), float(j.y), float(j.z))
		return null
	var parts := text.replace(",", " ").replace(";", " ").split(" ", false)
	if parts.size() < 3:
		return null
	if not (parts[0].is_valid_float() and parts[1].is_valid_float() and parts[2].is_valid_float()):
		return null
	return Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())


## Fallback so the game runs without touching Project Settings. If you define
## these actions in Project Settings > Input Map, this does nothing.
func _ensure_default_actions() -> void:
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	_add_action("dive", [space, click])
	_add_action("calibrate", [_key(KEY_C)])
	_add_action("restart", [_key(KEY_R)])
	_add_action("swap_ball", [_key(KEY_B)])


func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	return ev


func _add_action(action: String, events: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for ev in events:
		InputMap.action_add_event(action, ev)

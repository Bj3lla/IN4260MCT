extends Node
## Autoload "AccelInput".
## Listens for accelerometer samples over UDP and turns them into a single
## 0..1 `dive` value the ball uses. Spacebar works as a fallback.
##
## Accepted packet formats (one sample per packet, UTF-8 text):
##   "0.12,-0.40,9.81"            comma or space separated x,y,z
##   {"x":0.12,"y":-0.40,"z":9.81}  JSON
## Units don't matter much (m/s^2 or g) as long as threshold/full_scale match.

signal sample_received(accel: Vector3)

@export var port := 4242
## Which device axis counts as "pushing down". Flip the sign if it feels inverted.
@export var axis := Vector3(0, 0, 1)
## If true, uses total change in acceleration instead of a single axis (good for "shake/press" style devices).
@export var use_magnitude := false
## Change (relative to the calibrated rest value) needed before diving starts.
@export var threshold := 1.0
## Change that counts as full dive.
@export var full_scale := 5.0
## Higher = snappier response, lower = smoother.
@export var smoothing := 15.0
## Seconds without packets before the device is considered disconnected.
@export var timeout := 0.5

var raw := Vector3.ZERO
var baseline := Vector3.ZERO
var dive := 0.0            ## final smoothed value, 0..1
var device_dive := 0.0     ## unsmoothed value from the device only
var connected := false

var _udp := PacketPeerUDP.new()
var _last_packet_s := -1000.0
var _cal_left := 30        ## auto-calibrate on the first 30 samples
var _cal_sum := Vector3.ZERO
var _cal_n := 0


func _ready() -> void:
	_add_key_action("dive", KEY_SPACE)
	_add_key_action("calibrate", KEY_C)
	_add_key_action("restart", KEY_R)
	var err := _udp.bind(port)
	if err != OK:
		push_error("AccelInput: could not bind UDP port %d (error %d)" % [port, err])
	else:
		print("AccelInput: listening on UDP port %d" % port)


func calibrate(samples := 30) -> void:
	## Hold the device still in its "neutral" pose while this runs.
	_cal_left = samples
	_cal_sum = Vector3.ZERO
	_cal_n = 0


func is_calibrating() -> bool:
	return _cal_left > 0


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0

	while _udp.get_available_packet_count() > 0:
		var text := _udp.get_packet().get_string_from_utf8()
		var parsed = _parse(text)
		if parsed != null:
			_on_sample(parsed)
			_last_packet_s = now

	connected = now - _last_packet_s < timeout
	if not connected:
		device_dive = 0.0

	if Input.is_action_just_pressed("calibrate"):
		calibrate()

	var target := device_dive
	if Input.is_action_pressed("dive"):
		target = 1.0

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


func _parse(text: String):
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


func _add_key_action(action: String, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)

extends Node
## Autoload "AccelInput". Responsibility: turn input into one 0..1 value
## for 'diving' the softball and rigid ball. Input comes from the wristband IMU.
## Space / left mouse button is used as a input fallback.
##
## It creates one ServerScript (which owns UDP port 4242 and unpacks the packets)
## and listens to its update_IMU and update_HRT signals.
##
## Diving works by tilting the wrist: hold the tilt to keep diving. The tilt is
## measured relative to a calibrated rest pose (key C to recalibrate).

@export_group("Tilt")
## Device axis the wrist rotates about when you "dive". Flip the sign if inverted,
## or pick another axis if the tilt shows up elsewhere.
@export var tilt_axis := Vector3(1, 0, 0)
@export var tilt_threshold_deg := 15.0   ## tilt before diving starts
@export var tilt_full_deg := 50.0        ## tilt that counts as a full dive

@export_group("Response")
@export var smoothing := 15.0            ## higher = snappier, lower = smoother
@export var timeout := 0.5               ## seconds without IMU packets = disconnected
@export var calibration_samples := 30
## Print tilt / dive a few times per second to find the right axis and sign.
@export var debug_print := true # turn off when debugging and tuning is done :D

var orientation := Quaternion.IDENTITY          ## last orientation
var baseline_orientation := Quaternion.IDENTITY ## rest orientation
var tilt_deg := 0.0                             ## current tilt about tilt_axis
var heart_rate := 0.0
var hr_deviation := 0.0
var dive := 0.0            ## final smoothed value, 0..1
var device_dive := 0.0     ## unsmoothed value from the device only
var connected := false

var _server: ServerScript
var _last_packet_s := -1000.0
var _cal_left := 0
var _cal_n := 0
var _cal_q_sum := Vector4.ZERO
var _cal_q_ref := Quaternion.IDENTITY
var _debug_timer := 0.0


func _ready() -> void:
	_ensure_default_actions()

	_server = ServerScript.new()
	_server.process_priority = -10   # read packets before we use them this frame
	add_child(_server)
	_server.update_IMU.connect(_on_imu)
	_server.update_HRT.connect(_on_hrt)

	calibrate()   # calibrate on the first samples; press C to redo it


## Hold the wrist still in its neutral pose while this runs.
func calibrate() -> void:
	_cal_left = calibration_samples
	_cal_n = 0
	_cal_q_sum = Vector4.ZERO


## Only true while a device is actually streaming samples.
func is_calibrating() -> bool:
	return connected and _cal_left > 0


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	connected = now - _last_packet_s < timeout
	if not connected:
		device_dive = 0.0

	if Input.is_action_just_pressed("calibrate"):
		calibrate()

	var target := 1.0 if Input.is_action_pressed("dive") else device_dive
	dive = lerpf(dive, target, 1.0 - exp(-smoothing * delta))

	if debug_print and connected:
		_debug_timer -= delta
		if _debug_timer <= 0.0:
			_debug_timer = 0.25
			print("tilt %6.1f deg   device_dive %.2f   dive %.2f" % [tilt_deg, device_dive, dive])


# --- wristband data ----------------------------------------------------------

## vectors = [ax, ay, az, qw, qx, qy, qz]. Only the quaternion is used.
func _on_imu(vectors: Array) -> void:
	if vectors.size() < 7:
		return
	var q := Quaternion(vectors[4], vectors[5], vectors[6], vectors[3])   # Godot order is x, y, z, w
	if not q.is_finite() or q.length_squared() < 0.0001:
		return   # corrupt packet

	_last_packet_s = Time.get_ticks_msec() / 1000.0
	orientation = q.normalized()

	if _cal_left > 0:
		_accumulate_calibration(orientation)
		device_dive = 0.0
		return

	tilt_deg = _tilt_degrees(orientation)
	device_dive = clampf((tilt_deg - tilt_threshold_deg) / maxf(tilt_full_deg - tilt_threshold_deg, 0.001), 0.0, 1.0)


## vectors = [heart_rate, deviation], right?
func _on_hrt(vectors: Array) -> void:
	if vectors.size() >= 2:
		heart_rate = vectors[0]
		hr_deviation = vectors[1]


func _accumulate_calibration(q: Quaternion) -> void:
	if _cal_n == 0:
		_cal_q_ref = q
	# q and -q are the same rotation; flip so the average doesn't cancel out.
	var aligned := q if q.dot(_cal_q_ref) >= 0.0 else -q
	_cal_q_sum += Vector4(aligned.x, aligned.y, aligned.z, aligned.w)
	_cal_n += 1
	_cal_left -= 1

	var avg := _cal_q_sum / _cal_n
	baseline_orientation = Quaternion(avg.x, avg.y, avg.z, avg.w).normalized()


## Signed rotation (degrees) from the rest pose about tilt_axis, in the device's own frame.
func _tilt_degrees(q: Quaternion) -> float:
	var rel := (baseline_orientation.inverse() * q).normalized()
	if rel.w < 0.0:
		rel = -rel   # take the short way round
	var rotation_vector := rel.get_axis() * rel.get_angle()
	return rad_to_deg(rotation_vector.dot(tilt_axis.normalized()))


# --- keyboard / mouse fallback -----------------------------------------------

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

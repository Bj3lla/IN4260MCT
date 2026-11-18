class_name Camera
extends Camera2D
## Follows the ball. Leads it horizontally, keeps the view
## between the ball and the ground, and zooms out the higher it flies.
## Runs in the physics step so it stays in sync with the ball.

@export var world: World
@export var max_zoom := 0.85
@export var min_zoom := 0.22
@export var zoom_out_per_px := 1.0 / 3000.0   ## zoom lost per px above the ground baseline
@export var zoom_speed := 3.0
@export var follow_speed := 8.0
@export var look_ahead := 250.0          ## screen px ahead of the ball
@export var ground_bias := 0.4           ## 0 = centre on the ball, 1 = centre on the ground baseline

## Set at runtime by main.gd (the ball is spawned by Player). The first target snaps the
## camera into place; later ones (ball swaps) are followed smoothly.
var target: PlayerPhysics:
	set(value):
		target = value
		if target and not _snapped and is_node_ready():
			_snap_to_target()

var track: Track
var _snapped := false

func _ready() -> void:
	track = world.track
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = false   # smoothing is done below
	make_current()
	if target:
		_snap_to_target()


func _physics_process(delta: float) -> void:
	var z := lerpf(zoom.x, _target_zoom(), 1.0 - exp(-zoom_speed * delta))
	zoom = Vector2(z, z)
	position = position.lerp(_target_position(z), 1.0 - exp(-follow_speed * delta))

func _snap_to_target() -> void:
	var z := _target_zoom()
	zoom = Vector2(z,z)
	position = _target_position(z)
	_snapped = true

func _target_zoom() -> float:
	var height := track.base_y - target.global_position.y
	return clampf(max_zoom - height * zoom_out_per_px, min_zoom, max_zoom)


func _target_position(z: float) -> Vector2:
	return Vector2(target.global_position.x + look_ahead / z,
			lerpf(target.global_position.y, track.base_y, ground_bias))

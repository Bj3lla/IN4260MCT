class_name GameCamera
extends Camera2D
## Responsibility: follow the ball. Leads it horizontally, keeps the view
## between the ball and the ground, and zooms out the higher it flies.
## Runs in the physics step so it stays in sync with the ball.

@export var target: PlayerBase
@export var terrain: Hills               ## only used for its base_y
@export var max_zoom := 0.85
@export var min_zoom := 0.22
@export var zoom_out_per_px := 1.0 / 3000.0   ## zoom lost per px above the ground baseline
@export var zoom_speed := 3.0
@export var follow_speed := 8.0
@export var look_ahead := 250.0          ## screen px ahead of the ball
@export var ground_bias := 0.4           ## 0 = centre on the ball, 1 = centre on the ground baseline


func _ready() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = false   # smoothing is done below
	var z := _target_zoom()
	zoom = Vector2(z, z)
	position = _target_position(z)
	make_current()


func _physics_process(delta: float) -> void:
	var z := lerpf(zoom.x, _target_zoom(), 1.0 - exp(-zoom_speed * delta))
	zoom = Vector2(z, z)
	position = position.lerp(_target_position(z), 1.0 - exp(-follow_speed * delta))


func _target_zoom() -> float:
	var height := terrain.base_y - target.position.y
	return clampf(max_zoom - height * zoom_out_per_px, min_zoom, max_zoom)


func _target_position(z: float) -> Vector2:
	return Vector2(target.position.x + look_ahead / z,
			lerpf(target.position.y, terrain.base_y, ground_bias))

class_name SoftPlayer
extends PlayerBase
## Responsibility: the squishy ball's gameplay. Reads the soft body's state
## (average velocity, ground contacts), applies the shared rules from
## PlayerBase, and turns the results into forces on the centre point. The
## springs carry them to the outer points. The body itself lives in SoftBall.

const SOFT_BALL_SCENE := preload("res://soft_body_sim/soft_ball.tscn")
const SPEED_FLOOR_GAIN := 5.0    ## force per px/s below min_speed
const OVERSPEED_GAIN := 10.0     ## force per px/s above max_speed

@export var slope_thrust_strength := 2000.0  ## px/s² along a steep slope at full dive
@export var dive_squash := 0.0     ## extra push into the ground while diving (above ~0.3 the ring tends to fold)
@export var boost_time := 0.2      ## landing/launch kicks are spread over this many seconds
@export var max_correction := 10000.0  ## px/s² cap on min/max speed pushes (keeps the body from tearing)

var _soft: SoftBall
var _boost_force := Vector2.ZERO
var _boost_left := 0.0


func _ready() -> void:
	_soft = SOFT_BALL_SCENE.instantiate() as SoftBall
	_soft.spawn_position = global_position
	add_child(_soft)
	_soft.set_velocity(Vector2(tuning.start_speed, 0.0))


func _physics_process(delta: float) -> void:
	var dive := AccelInput.dive
	var mass := _soft.total_mass
	var v := _soft.average_velocity()
	linear_velocity = v
	global_position = _soft.center.global_position

	var contacts := _soft.terrain_normal()
	on_ground = contacts.length_squared() > 0.0001

	var force := Vector2.ZERO
	if on_ground:
		var n := up_normal(contacts)
		var t := tangent_of(n)
		var speed := v.dot(t)
		var change := touch_down(t)
		if change != 0.0:
			_boost(t * speed * change)
		force += t * slope_thrust(t, dive, speed, slope_thrust_strength) * mass
		force += -n * gravity * dive_squash * dive * mass
		if speed < tuning.min_speed:
			force += t * _floor_push(tuning.min_speed - speed) * mass
	else:
		if advance_air(delta, v, dive):
			_boost(Vector2(0.0, v.y * (tuning.launch_boost - 1.0)))
		# Every point already feels 1x gravity; add the difference.
		force.y += gravity * (tuning.air_gravity - 1.0 + tuning.air_dive_gravity * dive) * mass
		if v.x < tuning.min_speed:
			force.x += _floor_push(tuning.min_speed - v.x) * mass

	var over := v.length() - tuning.max_speed
	if over > 0.0:
		force -= v.normalized() * minf(over * OVERSPEED_GAIN, max_correction) * mass

	if _boost_left > 0.0:
		force += _boost_force
		_boost_left -= delta

	_soft.apply_force(force)
	_soft.set_color(dive_color(dive))


func _floor_push(deficit: float) -> float:
	return minf(deficit * SPEED_FLOOR_GAIN, max_correction)


## Spread a velocity change over boost_time so the centre doesn't punch through the ring.
func _boost(dv: Vector2) -> void:
	_boost_force = dv * _soft.total_mass / boost_time
	_boost_left = boost_time

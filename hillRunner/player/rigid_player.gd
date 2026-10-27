class_name RigidPlayer
extends PlayerBase
## Responsibility: the hard ball. A RigidBody2D with a hand-written integrator
## so it feels like ice: sliding never loses speed to friction or collisions,
## only slope gravity, diving, landings and launches change it.
##
## This node is a plain Node2D that follows the body, so it has the same shape
## as SoftPlayer. The body is top_level, so it ignores this node's transform.

@export var radius := 26.0
@export var base_gravity := 1.0            ## gravity scale while touching the ground
@export var slope_thrust_strength := 1200.0  ## px/s² along a steep slope at full dive

var _body: Body
var _velocity := Vector2.ZERO   ## the velocity we intend; the solver may disturb the body's own
var _spin := 0.0


## RigidBody2D that hands its integration step to the owning player.
class Body extends RigidBody2D:
	var integrate: Callable

	func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
		integrate.call(state)


func _ready() -> void:
	_velocity = Vector2(tuning.start_speed, 0.0)

	_body = Body.new()
	_body.integrate = _integrate
	_body.top_level = true
	_body.position = global_position
	_body.mass = 1.0
	_body.lock_rotation = true
	_body.can_sleep = false
	_body.custom_integrator = true
	_body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	_body.contact_monitor = true
	_body.max_contacts_reported = 4
	_body.physics_material_override = Ice.material()
	_body.linear_velocity = _velocity

	var shape := CircleShape2D.new()
	shape.radius = radius
	var col := CollisionShape2D.new()
	col.shape = shape
	_body.add_child(col)
	add_child(_body)


func _physics_process(delta: float) -> void:
	position = _body.global_position
	linear_velocity = _body.linear_velocity
	_spin += linear_velocity.x / radius * delta
	queue_redraw()


func _integrate(state: PhysicsDirectBodyState2D) -> void:
	var dt := state.step
	var dive := AccelInput.dive
	var v := _velocity

	var summed := Vector2.ZERO
	for i in state.get_contact_count():
		summed += state.get_contact_local_normal(i)
	on_ground = summed.length_squared() > 0.0001

	if on_ground:
		var t := tangent_of(up_normal(summed))
		var speed := v.length() * (1.0 + touch_down(t))
		# Ice: keep all speed; only slope gravity and diving change it.
		speed += (gravity * base_gravity * t.y + slope_thrust(t, dive, speed, slope_thrust_strength)) * dt
		speed = clampf(speed, tuning.min_speed, tuning.max_speed)
		v = t * speed
	else:
		if advance_air(dt, v, dive):
			v.y *= tuning.launch_boost
		v.y += gravity * (tuning.air_gravity + tuning.air_dive_gravity * dive) * dt
		v.x = maxf(v.x, tuning.min_speed)
		v = v.limit_length(tuning.max_speed)

	_velocity = v
	state.linear_velocity = v


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, dive_color(AccelInput.dive))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color.WHITE, 3.0, true)
	var dir := Vector2.from_angle(_spin)
	draw_line(-dir * radius * 0.8, dir * radius * 0.8, Color(1, 1, 1, 0.8), 4.0, true)
	draw_circle(dir.orthogonal() * radius * 0.45, 4.0, Color.WHITE)

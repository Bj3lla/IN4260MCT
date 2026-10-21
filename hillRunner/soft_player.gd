extends Node2D
## Squishy version of the player (see ball.gd for the rigid one).
## Spawns soft_body_sim/soft_ball.tscn and plays by the same rules: dive on
## downslopes, release on upslopes, landing bonus/penalty.
##
## All forces go to the center rigid ball (soft_ball.rigid_balls[0]) through
## soft_ball.apply_force(). The springs carry them to the outer points.
## This node's position follows the center ball, so main.gd can treat it like
## the rigid ball (position, linear_velocity, landed signal).

signal landed(kind: String, change: float)

const SoftBallScene := preload("res://soft_body_sim/soft_ball.tscn")
const SoftBall := preload("res://soft_body_sim/soft_ball.gd")

@export_group("Shape")
@export var ball_radius := 45.0      ## distance from center to the outer points
@export var point_radius := 10.0     ## collision radius of each point
@export var num_points := 10
@export var stiffness := 1000.0      ## higher = less squishy
@export var damping := 0.9
## Masses of the center ball and each outer point. (A heavy center + light ring
## was tested and folded more easily, so they're equal by default.)
@export var center_mass := 1.0
@export var point_mass := 1.0
## Extra springs from each outer point to the one two steps away.
## Without them the ring can fold flat on hard landings and stay folded.
@export var brace_springs := true
@export var brace_stiffness := 1000.0

@export_group("Movement")
@export var air_gravity := 0.8       ## gravity scale while flying (lower = floatier)
@export var air_dive_gravity := 2.5  ## extra gravity in the air while diving
@export var dive_squash := 0.0       ## extra push into the ground while diving (above ~0.3 the ring tends to fold)
@export var slope_thrust := 700.0    ## px/s² along the hill at full dive on a steep slope
@export var uphill_brake := 1.3
@export var steep_slope := 0.6
@export var launch_boost := 1.2
@export var min_launch_vy := 150.0
@export var landing_bonus := 0.15
@export var landing_penalty := 0.4
@export var min_air_time := 0.12
@export var min_speed := 180.0
@export var max_speed := 1500.0
@export var boost_time := 0.2        ## landing/launch kicks are spread over this many seconds
@export var max_correction := 1500.0 ## px/s² cap on the min/max speed pushes (keeps the body from tearing)

var soft_ball: SoftBall
var center: RigidBody2D
var linear_velocity := Vector2.ZERO  ## average velocity of all points
var on_ground := false
var air_time := 0.0

var _g := 980.0
var _total_mass := 1.0
var _boost_force := Vector2.ZERO
var _boost_left := 0.0


func _ready() -> void:
	_g = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)

	soft_ball = SoftBallScene.instantiate() as SoftBall
	# Configure before it builds itself in _ready.
	var chord := 2.0 * ball_radius * sin(PI / num_points)
	soft_ball.radius = ball_radius
	soft_ball.num_points = num_points
	soft_ball.points_min_distance = point_radius
	soft_ball.outer_spring_length = chord
	soft_ball.outer_spring_max_length = chord
	soft_ball.inner_spring_length = ball_radius
	soft_ball.inner_spring_max_length = ball_radius
	soft_ball.outer_spring_stiffness = stiffness
	soft_ball.inner_spring_stiffness = stiffness
	soft_ball.spring_damping = damping
	add_child(soft_ball)

	center = soft_ball.rigid_balls[0]
	if brace_springs:
		_add_brace_springs()
	# Visuals copy the center ball's transform; its rotation would twist the outline.
	soft_ball.remote_transform.update_rotation = false

	var mat := PhysicsMaterial.new()
	mat.friction = 0.0
	mat.bounce = 0.0
	_total_mass = 0.0
	# The soft ball is a plain Node, so its bodies don't inherit our transform.
	# Move them all to the spawn point (same offset keeps the springs intact).
	center.mass = center_mass
	for b: RigidBody2D in soft_ball.rigid_balls:
		if b != center:
			b.mass = point_mass
		b.global_position += global_position
		b.physics_material_override = mat
		b.can_sleep = false
		b.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
		b.contact_monitor = true
		b.max_contacts_reported = 2
		b.linear_velocity = Vector2(250, 0)
		_total_mass += b.mass

	soft_ball.line.default_color = Color.WHITE
	soft_ball.line.width = 3.0


func _add_brace_springs() -> void:
	var balls := soft_ball.rigid_balls
	var k := balls.size() - 1
	var brace_len := 2.0 * ball_radius * sin(2.0 * PI / num_points)
	for i in range(k):
		var a := balls[1 + i]
		var b := balls[1 + (i + 2) % k]
		var spring := soft_ball.make_spring(a, b, brace_len, brace_len, brace_stiffness)
		soft_ball.add_child(spring)


func _physics_process(delta: float) -> void:
	var dive := AccelInput.dive
	var balls: Array[RigidBody2D] = soft_ball.rigid_balls

	# Average velocity of the whole body (the center alone jiggles a lot).
	var v := Vector2.ZERO
	for b in balls:
		v += b.linear_velocity
	v /= balls.size()
	linear_velocity = v
	position = center.global_position

	# Average contact normal of the outer points against the terrain.
	# (Outer points bumping into each other don't count.)
	var n := Vector2.ZERO
	for i in range(1, balls.size()):
		var state := PhysicsServer2D.body_get_direct_state(balls[i].get_rid())
		for c in state.get_contact_count():
			if not state.get_contact_collider_object(c) is RigidBody2D:
				n += state.get_contact_local_normal(c)
	on_ground = n.length_squared() > 0.0001

	var force := Vector2.ZERO
	if on_ground:
		n = n.normalized()
		if n.y > 0:
			n = -n
		var t := Vector2(-n.y, n.x)        # tangent along the hill
		if t.x < 0:
			t = -t
		var speed := v.dot(t)
		if air_time >= min_air_time:
			_landing(speed, t)
		air_time = 0.0
		var slope := clampf(t.y / steep_slope, -1.0, 1.0)   # +1 steep down, -1 steep up
		var thrust := dive * slope_thrust * slope
		if slope < 0.0:
			# Braking only slows us down to min_speed, never pushes us backwards.
			thrust *= uphill_brake if speed > min_speed else 0.0
		force += t * thrust * _total_mass
		force += -n * _g * dive_squash * dive * _total_mass
		if speed < min_speed:
			force += t * minf((min_speed - speed) * 5.0, max_correction) * _total_mass
	else:
		var was := air_time
		air_time += delta
		if was < 0.05 and air_time >= 0.05 and -v.y > min_launch_vy and dive < 0.3:
			_boost(Vector2(0, v.y * (launch_boost - 1.0)))
		# Gravity already pulls every point at 1x; add the difference.
		force.y += _g * (air_gravity - 1.0 + air_dive_gravity * dive) * _total_mass
		if v.x < min_speed:
			force.x += minf((min_speed - v.x) * 5.0, max_correction) * _total_mass

	var over := v.length() - max_speed
	if over > 0.0:
		force -= v.normalized() * minf(over * 10.0, max_correction) * _total_mass

	if _boost_left > 0.0:
		force += _boost_force
		_boost_left -= delta

	soft_ball.apply_force(force)

	var body_col := Color("#3b4a6b").lerp(Color("#d94a4a"), dive)
	soft_ball.polygon.color = body_col


## Spread a velocity change over boost_time so the center ball doesn't punch through the ring.
func _boost(dv: Vector2) -> void:
	_boost_force = dv * _total_mass / boost_time
	_boost_left = boost_time


func _landing(speed: float, t: Vector2) -> void:
	var slope := t.y   # > 0 means the hill goes down to the right
	var k := clampf(absf(slope) / steep_slope, 0.0, 1.0)
	var change := 0.0
	var kind := "flat"
	if slope > 0.05:
		change = landing_bonus * k
		kind = "great" if k > 0.6 else "good"
	elif slope < -0.05:
		change = -landing_penalty * k
		kind = "bad"
	landed.emit(kind, change)
	if change != 0.0:
		_boost(t * speed * change)

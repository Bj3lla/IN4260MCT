class_name SoftBall
extends PlayerPhysics
## The squishy player ball. A centre point plus a ring of points joined by
## springs, drawn as a smooth, textured outline. Each physics frame it reads the
## body's state (average velocity, ground contacts), applies the shared rules
## from PlayerPhysics, and pushes the centre point; the springs carry the force
## to the outer points.
##
## Scene: a PlayerPhysics root with this script and a child AudioStreamPlayer
## named sfx_jump. The points, springs and visuals are built in code.

const CHARACTER_TEXTURE: Texture2D = preload("res://refactor/visuals/Ball character.svg")
const SPEED_FLOOR_GAIN := 5.0    ## force per px/s below min_speed
const OVERSPEED_GAIN := 10.0     ## force per px/s above max_speed

@export_group("Gameplay")
@export var slope_thrust_strength := 2000.0  ## px/s² along a steep slope at full dive
@export var dive_squash := 0.0     ## extra push into the ground while diving (above ~0.3 the ring tends to fold)
@export var boost_time := 0.2      ## landing/launch kicks are spread over this many seconds
@export var max_correction := 10000.0  ## px/s² cap on min/max speed pushes (keeps the body from tearing)

@export_group("Shape")
@export var ball_radius := 20.0      ## centre to the outer points
@export var point_radius := 10.0     ## collision radius of each point
@export var num_points := 10
@export var stiffness := 1200.0      ## higher = less squishy
@export var damping := 0.4
@export var center_mass := 0.6
@export var point_mass := 0.5
## Springs to the point two steps away, so the ring can't fold flat on hard landings.
@export var brace_springs := true
@export var brace_stiffness := 3000.0

@export_group("Outline")
@export var outline_color := Color.WHITE
@export var outline_width := 3.0
@export var outline_curvature := 10.0  ## handle length of the smoothed corners

var center: RigidBody2D
var ring: Array[RigidBody2D] = []
var total_mass := 0.0

var _boost_force := Vector2.ZERO
var _boost_left := 0.0

## Plain Node holding the points, springs and visuals. Being a plain Node, it
## breaks the transform chain, so they stay in world coordinates while this
## node moves to follow the centre point.
var _body := Node.new()
var _ice := PhysicsMaterial.new()      # slippery: no friction (bounce is 0 by default)
var _curve := Curve2D.new()
var _polygon := Polygon2D.new()
var _line := Line2D.new()

@onready var sfx_jump: AudioStreamPlayer = $sfx_jump


func _ready() -> void:
	_ice.friction = 0.0
	add_child(_body)

	center = _make_point(global_position, center_mass)
	for i in num_points:
		var offset := Vector2.from_angle(TAU * i / num_points) * ball_radius
		ring.append(_make_point(global_position + offset, point_mass))
	total_mass = center_mass + point_mass * num_points

	for i in num_points:
		_add_spring(center, ring[i], stiffness)
		_add_spring(ring[i], ring[(i + 1) % num_points], stiffness)
		if brace_springs:
			_add_spring(ring[i], ring[(i + 2) % num_points], brace_stiffness)

	_polygon.texture = CHARACTER_TEXTURE
	_line.default_color = outline_color
	_line.width = outline_width
	_body.add_child(_polygon)
	_body.add_child(_line)

	for p in [center] + ring:
		p.linear_velocity = Vector2(tuning.start_speed, 0.0)


# --- gameplay ----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var dive := AccelInput.dive
	var v := _average_velocity()
	linear_velocity = v
	global_position = center.global_position

	var contacts := _terrain_normal()
	on_ground = contacts.length_squared() > 0.0001

	var force := Vector2.ZERO
	if on_ground:
		var n := up_normal(contacts)
		var t := tangent_of(n)
		var speed := v.dot(t)
		var change := touch_down(t)
		if change != 0.0:
			_boost(t * speed * change)
		force += t * slope_thrust(t, dive, speed, slope_thrust_strength) * total_mass
		force += -n * gravity * dive_squash * dive * total_mass
		if speed < tuning.min_speed:
			force += t * _floor_push(tuning.min_speed - speed) * total_mass
	else:
		if advance_air(delta, v, dive):
			sfx_jump.play()
			_boost(Vector2(0.0, v.y * (tuning.launch_boost - 1.0)))
		# Every point already feels 1x gravity; add the difference.
		force.y += gravity * (tuning.air_gravity - 1.0 + tuning.air_dive_gravity * dive) * total_mass
		if v.x < tuning.min_speed:
			force.x += _floor_push(tuning.min_speed - v.x) * total_mass

	var over := v.length() - tuning.max_speed
	if over > 0.0:
		force -= v.normalized() * minf(over * OVERSPEED_GAIN, max_correction) * total_mass

	if _boost_left > 0.0:
		force += _boost_force
		_boost_left -= delta

	center.apply_central_force(force)
	_polygon.color = dive_color(dive)


func _floor_push(deficit: float) -> float:
	return minf(deficit * SPEED_FLOOR_GAIN, max_correction)


## Spread a velocity change over boost_time so the centre doesn't punch through the ring.
func _boost(dv: Vector2) -> void:
	_boost_force = dv * total_mass / boost_time
	_boost_left = boost_time


func _average_velocity() -> Vector2:
	var sum := center.linear_velocity
	for p in ring:
		sum += p.linear_velocity
	return sum / (ring.size() + 1)


## Sum of contact normals of the outer points against anything that isn't
## another soft point (so: the terrain). Zero when airborne.
func _terrain_normal() -> Vector2:
	var summed := Vector2.ZERO
	for p in ring:
		var state := PhysicsServer2D.body_get_direct_state(p.get_rid())
		for c in state.get_contact_count():
			if not state.get_contact_collider_object(c) is RigidBody2D:
				summed += state.get_contact_local_normal(c)
	return summed


# --- construction ------------------------------------------------------------

func _make_point(pos: Vector2, mass: float) -> RigidBody2D:
	var circle := CircleShape2D.new()
	circle.radius = point_radius
	var collision := CollisionShape2D.new()
	collision.shape = circle

	var p := RigidBody2D.new()
	p.add_child(collision)
	p.position = pos
	p.mass = mass
	p.physics_material_override = _ice
	p.can_sleep = false
	p.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	p.contact_monitor = true          # needed by _terrain_normal()
	p.max_contacts_reported = 2
	_body.add_child(p)
	return p


## The rest length is the current distance, since points are spawned at rest.
## A spring joint sits on body a, with its local +Y axis pointing at body b.
func _add_spring(a: RigidBody2D, b: RigidBody2D, k: float) -> void:
	var spring := DampedSpringJoint2D.new()
	spring.position = a.position
	spring.rotation = (b.position - a.position).angle() - PI / 2.0
	spring.length = a.position.distance_to(b.position)
	spring.rest_length = spring.length
	spring.stiffness = k
	spring.damping = damping
	spring.node_a = a.get_path()
	spring.node_b = b.get_path()
	_body.add_child(spring)


# --- outline -----------------------------------------------------------------

func _process(_delta: float) -> void:
	# Ring points pushed outward by the point radius, so the outline wraps the circles.
	var pts := PackedVector2Array()
	for p in ring:
		pts.append(p.position + (p.position - center.position).normalized() * point_radius)

	# Smooth closed curve: each handle follows the line from the previous to the next point.
	_curve.clear_points()
	for i in num_points + 1:              # +1: repeat the first point to close the loop
		var tangent := (pts[(i + 1) % num_points] - pts[i - 1]).normalized() * outline_curvature
		_curve.add_point(pts[i % num_points], -tangent, tangent)

	var baked := _curve.get_baked_points()
	_polygon.polygon = baked
	_line.points = baked

	# Stretch the texture over the polygon's bounds so the character squishes with the body.
	var bounds := Rect2(baked[0], Vector2.ZERO)
	for point in baked:
		bounds = bounds.expand(point)
	var uvs := PackedVector2Array()
	for point in baked:
		uvs.append((point - bounds.position) / bounds.size * CHARACTER_TEXTURE.get_size())
	_polygon.uv = uvs

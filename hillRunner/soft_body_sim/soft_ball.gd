class_name SoftBall
extends Node
## Responsibility: the soft body itself. A centre point plus a ring of points
## joined by springs, and the smooth outline drawn around them. It knows
## nothing about gameplay; SoftPlayer drives it through the small API below.
##
## Scene soft_ball.tscn: a plain Node root with
##   Visuals (Node2D) > Polygon2D, Line2D, Path2D
## The root must be a plain Node (not Node2D) so the points keep world coordinates.

const POINT_SCENE := preload("res://soft_body_sim/soft_point.tscn")

@export_group("Shape")
@export var ball_radius := 45.0      ## centre to the outer points
@export var point_radius := 10.0     ## collision radius of each point
@export var num_points := 10
@export var stiffness := 1000.0      ## higher = less squishy
@export var damping := 0.9
@export var center_mass := 1.0
@export var point_mass := 1.0
## Springs from each outer point to the one two steps away. Without them
## the ring can fold flat on hard landings and stay folded.
@export var brace_springs := true
@export var brace_stiffness := 1000.0

@export_group("Outline")
@export var outline_color := Color.WHITE
@export var outline_width := 3.0
@export var outline_curvature := 10.0  ## handle length of the smoothed corners

var spawn_position := Vector2.ZERO     ## set before add_child()
var center: SoftPoint
var ring: Array[SoftPoint] = []
var total_mass := 0.0

@onready var _visuals: Node2D = $Visuals
@onready var _polygon: Polygon2D = $Visuals/Polygon2D
@onready var _line: Line2D = $Visuals/Line2D
@onready var _path: Path2D = $Visuals/Path2D


func _ready() -> void:
	_build_points()
	_build_springs()
	_build_outline()


# --- API for the player ------------------------------------------------------

func apply_force(force: Vector2) -> void:
	center.apply_central_force(force)


func set_velocity(v: Vector2) -> void:
	center.linear_velocity = v
	for p in ring:
		p.linear_velocity = v


func average_velocity() -> Vector2:
	var sum := center.linear_velocity
	for p in ring:
		sum += p.linear_velocity
	return sum / (ring.size() + 1)


## Sum of contact normals of the outer points against anything that isn't
## another soft point (so: the terrain). Zero when airborne.
func terrain_normal() -> Vector2:
	var summed := Vector2.ZERO
	for p in ring:
		var state := PhysicsServer2D.body_get_direct_state(p.get_rid())
		for c in state.get_contact_count():
			if not state.get_contact_collider_object(c) is RigidBody2D:
				summed += state.get_contact_local_normal(c)
	return summed


func set_color(color: Color) -> void:
	_polygon.color = color


# --- construction ------------------------------------------------------------

func _build_points() -> void:
	center = _make_point(spawn_position, center_mass)
	for i in num_points:
		var offset := Vector2.RIGHT.rotated(TAU / num_points * i) * ball_radius
		ring.append(_make_point(spawn_position + offset, point_mass))
	total_mass = center_mass + point_mass * num_points

	# The outline follows the centre point (position only, no rotation).
	var follower := RemoteTransform2D.new()
	follower.update_rotation = false
	center.add_child(follower)
	follower.remote_path = follower.get_path_to(_visuals)


func _make_point(pos: Vector2, mass: float) -> SoftPoint:
	var p := POINT_SCENE.instantiate() as SoftPoint
	p.radius = point_radius
	p.mass = mass
	p.position = pos
	add_child(p)
	return p


func _build_springs() -> void:
	var side := 2.0 * ball_radius * sin(PI / num_points)         # neighbour distance
	var brace := 2.0 * ball_radius * sin(2.0 * PI / num_points)  # two-steps-away distance
	for i in num_points:
		var p := ring[i]
		_add_spring(p, ring[(i + 1) % num_points], side, stiffness)
		_add_spring(center, p, ball_radius, stiffness)
		if brace_springs:
			_add_spring(p, ring[(i + 2) % num_points], brace, brace_stiffness)


## A spring joint is placed midway between its two bodies and rotated to point from one to the other.
func _add_spring(a: RigidBody2D, b: RigidBody2D, length: float, k: float) -> void:
	var spring := DampedSpringJoint2D.new()
	spring.node_a = a.get_path()
	spring.node_b = b.get_path()
	spring.length = length
	spring.rest_length = length
	spring.stiffness = k
	spring.damping = damping
	spring.disable_collision = true
	var dir := (b.position - a.position).normalized()
	spring.position = (a.position + b.position) * 0.5 - dir * length * 0.5
	spring.rotation = dir.angle() - PI / 2.0
	add_child(spring)


func _build_outline() -> void:
	_path.curve = Curve2D.new()   # own curve per ball: never shared between instances
	for i in num_points + 1:      # +1: the last point repeats the first to close the loop
		_path.curve.add_point(Vector2.ZERO)
	_line.default_color = outline_color
	_line.width = outline_width


# --- outline -----------------------------------------------------------------

func _process(_delta: float) -> void:
	var curve := _path.curve
	for i in num_points:
		var cur := _outline_point(i)
		var prev := _outline_point(posmod(i - 1, num_points))
		var next := _outline_point((i + 1) % num_points)
		# Handles are perpendicular to the radius; the sign follows whether the corner bends left or right.
		var turn := signf((cur - prev).angle_to(next - cur))
		var handle := cur.orthogonal().normalized() * outline_curvature * turn
		curve.set_point_position(i, cur)
		curve.set_point_in(i, handle)
		curve.set_point_out(i, -handle)
	curve.set_point_position(num_points, curve.get_point_position(0))
	curve.set_point_in(num_points, curve.get_point_in(0))
	curve.set_point_out(num_points, curve.get_point_out(0))

	var baked := curve.get_baked_points()
	_polygon.polygon = baked
	_line.points = baked


## Ring point i relative to the centre, pushed outward by the point radius so the outline wraps the collision circles.
func _outline_point(i: int) -> Vector2:
	var d := ring[i].position - center.position
	return d + d.normalized() * point_radius

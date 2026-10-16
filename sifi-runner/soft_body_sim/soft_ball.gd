extends Node

@export_group("Circle Properties")
@export_range(0.0, 1000000.0) var radius : float = 100.0
@export_range(5, 10000) var num_points : int = 15
# the points are circle shaped rigid bodies. this gives the redius of these circles
@export_range(10, 1000000) var points_min_distance : float = 30.0

@export_group("Outer Springs Properties")
@export_range(0.0, 1000000.0) var outer_spring_length : float = 42.0
@export_range(0.0, 1000000.0) var outer_spring_max_length : float = 42.0
@export_range(0.0, 1000000.0) var outer_spring_stiffness : float = 200.0


@export_group("Inner Spring Properties")
@export_range(0.0, 1000000.0) var inner_spring_length : float = 100.0
@export_range(0.0, 1000000.0) var inner_spring_max_length : float = 100.0
@export_range(0.0, 1000000.0) var inner_spring_stiffness : float = 200.0

@export_group("General Spring Properties")
## wobblyness of the ball
@export_range(0.0, 1.0) var spring_damping : float = 0.9

@export_group("Graphics Properties")
# how many pixels apart the actually drawn points from the curve should be
@export var curve_bake_interval : float = 10.0
@export var curve_point_curvature : float = 10.0

# variables for physics
var rigid_ball : PackedScene = preload("res://soft_body_sim/rigid_ball.tscn") # "points" of the softbody simulation
var rigid_balls : Array[RigidBody2D]
var outer_springs : Array[DampedSpringJoint2D]
var center_springs : Array[DampedSpringJoint2D]

# variables for graphics
var visuals_container : Node2D
var path : Path2D
var polygon : Polygon2D
var line : Line2D
var remote_transform : RemoteTransform2D

func _ready() -> void:
	
	# GRAPHICS INITIALIZATION ---
	
	# initialize curve points for graphics
	# gets updated in _process
	# since we have a fixed number of balls, the curve has a fixed number of points
	visuals_container = $Visuals
	polygon = $Visuals/Polygon2D
	line = $Visuals/Line2D
	path = $Visuals/Path2D
	for i in range(num_points+1):
		path.curve.add_point(Vector2(0,0))
	
	# PHYSICS INITIALIZATION ---
	
	# zeroth entry will be the center ball
	# following entries are outer balls in order around a circle
	rigid_balls = []
	
	outer_springs = []
	center_springs = []
	
	# make center point
	var center_ball : RigidBody2D = rigid_ball.instantiate()
	center_ball.position = Vector2(0.0, 0.0)
	center_ball.radius = points_min_distance
	add_child(center_ball)
	rigid_balls.append(center_ball)
	remote_transform = RemoteTransform2D.new()
	center_ball.add_child(remote_transform)
	remote_transform.remote_path = "../../Visuals"
	
	# initialize equally spaced points on circle
	for i in range(num_points):
		var point_position : Vector2 = radius*Vector2(1.0, 0.0) # position of point
		point_position = point_position.rotated(2*PI / (num_points)*i) # position points equally spaced on circle
		var point_ball : RigidBody2D = rigid_ball.instantiate()
		point_ball.position = point_position
		point_ball.radius = points_min_distance
		add_child(point_ball)
		rigid_balls.append(point_ball)
	
	# make springs between neighbourign outer points
	# and between each outer point and the center point
	var outer_point : RigidBody2D = rigid_balls[0]
	var right_neighbour : RigidBody2D = rigid_balls[1]
	for i in range(1, num_points):
		
		outer_point = right_neighbour
		right_neighbour = rigid_balls[i+1]
		
		# initialize outer spring between neighbours
		var outer_spring : DampedSpringJoint2D = make_spring(outer_point, right_neighbour, outer_spring_length, outer_spring_max_length, outer_spring_stiffness)
		add_child(outer_spring)
		outer_springs.append(outer_spring)
		
		# initialize spring between center and outer point
		var center_spring : DampedSpringJoint2D = make_spring(center_ball, outer_point, inner_spring_length, inner_spring_max_length, inner_spring_stiffness)
		add_child(center_spring)
		center_springs.append(center_spring)
	
	outer_point = right_neighbour
	right_neighbour = rigid_balls[1]
	var outer_spring : DampedSpringJoint2D = make_spring(outer_point, right_neighbour, outer_spring_length, outer_spring_max_length, outer_spring_stiffness)
	add_child(outer_spring)
	outer_springs.append(outer_spring)
	
	var center_spring : DampedSpringJoint2D = make_spring(center_ball, outer_point, inner_spring_length, inner_spring_max_length, inner_spring_stiffness)
	add_child(center_spring)
	center_springs.append(center_spring)
	
	#get_tree().paused = true

# makes a spring with given properties in the middle between two balls
# a spring connects to physics objects and has its own position and rotation
func make_spring(rigid_ball_a : RigidBody2D, rigid_ball_b : RigidBody2D, spring_length : float, spring_max_length : float, spring_stiffness : float) -> DampedSpringJoint2D:
	# initialize spring
	var spring : DampedSpringJoint2D = DampedSpringJoint2D.new()
	spring.node_a = rigid_ball_a.get_path()
	spring.node_b = rigid_ball_b.get_path()
	spring.length = spring_max_length
	spring.rest_length = spring_length
	spring.stiffness = spring_stiffness
	spring.damping = spring_damping
	spring.disable_collision = true
	
	# position and rotate spring into the middle of both balls
	var middle_point : Vector2 = 0.5 * (rigid_ball_a.position + rigid_ball_b.position)
	var difference_direction : Vector2 = (rigid_ball_b.position - rigid_ball_a.position).normalized()
	spring.position = middle_point - 0.5 * spring_length * difference_direction
	spring.rotation = difference_direction.angle() - PI / 2.0
	
	return spring

# Curve points have a position and additionally in and out positions,
# that define the curvature of the corner at this point.
# This function heuristically calculates them,
# by assuming the line between the in and out point is orthogonal to the
# distance between the point and the center of the ball.
# the parameter convex_or_concave needs to be 1.0 or -1.0
# and changes between convex and concave curvature
func get_in_and_out_curve_point(point : Vector2, convex_or_concave : float = 1.0) -> Array[Vector2]:
	# calculate direction between in and out point
	var direction : Vector2 = point.orthogonal().normalized()
	var in_point : Vector2 = convex_or_concave * direction*curve_point_curvature
	var out_point : Vector2 = -convex_or_concave * direction*curve_point_curvature
	return [in_point, out_point]

func _process(delta: float) -> void:
	# update overall position with position from center ball
	#position += rigid_balls[0].position
	
	# get current positions of outer balls
	# and update path.curve
	
	var center_position : Vector2 = rigid_balls[0].position
	
	var last_point : Vector2 = rigid_balls[-1].position - center_position
	var current_point : Vector2 = rigid_balls[1].position - center_position
	var next_point : Vector2 = rigid_balls[2].position - center_position
	
	last_point += points_min_distance * last_point.normalized()
	current_point += points_min_distance * current_point.normalized()
	next_point += points_min_distance * next_point.normalized()
	
	path.curve.set_point_position(0, current_point)
	path.curve.set_point_position(num_points, current_point)
	var angle_at_point : float = (current_point - last_point).angle_to(next_point - current_point)
	var in_and_out_point : Array[Vector2] = get_in_and_out_curve_point(current_point, sign(angle_at_point))
	path.curve.set_point_in(num_points, in_and_out_point[0])
	path.curve.set_point_out(0, in_and_out_point[1])
	
	for i in range(3, num_points+1):
		
		last_point = current_point
		current_point = next_point
		next_point = rigid_balls[i].position - center_position
		
		next_point += points_min_distance * next_point.normalized()
		
		path.curve.set_point_position(i-2, current_point)
		angle_at_point= (current_point - last_point).angle_to(next_point - current_point)
		in_and_out_point = get_in_and_out_curve_point(current_point, sign(angle_at_point))
		path.curve.set_point_in(i-2, in_and_out_point[0])
		path.curve.set_point_out(i-2, in_and_out_point[1])
	
	last_point = current_point
	current_point = next_point
	next_point = rigid_balls[1].position - center_position
	
	next_point += points_min_distance * next_point.normalized()
	
	path.curve.set_point_position(num_points-1, current_point)
	angle_at_point = (current_point - last_point).angle_to(next_point - current_point)
	in_and_out_point = get_in_and_out_curve_point(current_point, sign(angle_at_point))
	path.curve.set_point_in(num_points-1, in_and_out_point[0])
	path.curve.set_point_out(num_points-1, in_and_out_point[1])
	
	# update polygon
	var baked_points = path.curve.get_baked_points()
	polygon.polygon = baked_points
	line.points = baked_points
	
	
	
	
	
	
	

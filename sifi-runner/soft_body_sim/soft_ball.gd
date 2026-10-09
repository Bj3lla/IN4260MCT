extends Node2D

@export_group("Circle Properties")
@export_range(0.0, 1000000.0) var radius : float = 100.0
@export_range(2, 10000) var num_points : int = 10

@export_group("Spring Properties")
@export_range(0.0, 1000000.0) var spring_length : float = 100.0
@export_range(0.0, 1000000.0) var spring_stiffness : float = 200.0
@export_range(0.0, 1.0) var spring_damping : float = 0.9

var rigid_ball : PackedScene = preload("res://soft_body_sim/rigid_ball.tscn") # "points" of the softbody simulation

func _ready() -> void:
	var rigid_balls : Array[RigidBody2D] = []
	var outer_springs : Array[DampedSpringJoint2D] = []
	var center_springs : Array[DampedSpringJoint2D] = []
	
	# make center point
	var center_ball : RigidBody2D = rigid_ball.instantiate()
	center_ball.position = Vector2(0.0, 0.0)
	add_child(center_ball)
	rigid_balls.append(center_ball)
	
	# initialize equally spaced points on circle
	for i in range(num_points):
		var point_position : Vector2 = radius*Vector2(1.0, 0.0) # position of point
		point_position = point_position.rotated(2*PI / (num_points)*i) # position points equally spaced on circle
		var point_ball : RigidBody2D = rigid_ball.instantiate()
		point_ball.position = point_position
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
		var outer_spring : DampedSpringJoint2D = make_spring(outer_point, right_neighbour)
		add_child(outer_spring)
		outer_springs.append(outer_spring)
		
		# initialize spring between center and outer point
		var center_spring : DampedSpringJoint2D = make_spring(center_ball, outer_point)
		add_child(center_spring)
		center_springs.append(center_spring)
	
	outer_point = right_neighbour
	right_neighbour = rigid_balls[1]
	var outer_spring : DampedSpringJoint2D = make_spring(outer_point, right_neighbour)
	add_child(outer_spring)
	outer_springs.append(outer_spring)
	
	var center_spring : DampedSpringJoint2D = make_spring(center_ball, outer_point)
	add_child(center_spring)
	center_springs.append(center_spring)
	
	#get_tree().paused = true

func make_spring(rigid_ball_a : RigidBody2D, rigid_ball_b : RigidBody2D) -> DampedSpringJoint2D:
	# initialize spring
	var spring : DampedSpringJoint2D = DampedSpringJoint2D.new()
	spring.node_a = rigid_ball_a.get_path()
	spring.node_b = rigid_ball_b.get_path()
	spring.length = spring_length
	spring.stiffness = spring_stiffness
	spring.damping = spring_damping
	
	# position and rotate spring into the middle of both balls
	var middle_point : Vector2 = 0.5 * (rigid_ball_a.position + rigid_ball_b.position)
	var difference_direction : Vector2 = (rigid_ball_b.position - rigid_ball_a.position).normalized()
	spring.position = middle_point - 0.5 * spring_length * difference_direction
	spring.rotation = difference_direction.angle() - PI / 2.0
	
	return spring

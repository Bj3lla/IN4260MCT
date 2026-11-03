extends Node2D

@export var terrain_speed : float = 1.0
@export var air_friction_constant = 0.05
@export var ball_horizontal_force : float = -100.0

const SOFT_BALL_SCENE := preload("res://soft_body_sim/soft_ball.tscn")
var soft_ball : SoftBall
var dive : float
var terrain : Terrain
var num_soft_ball_points : int
var boost : Vector2

func _ready() -> void:
	dive = AccelInput.dive
	boost = Vector2(0.0, 0.0)
	
	terrain = Terrain.new()
	terrain.rotation_degrees = 20
	add_child(terrain)
	
	soft_ball = SOFT_BALL_SCENE.instantiate() as SoftBall
	soft_ball.spawn_position = Vector2(500.0, 300.0)
	add_child(soft_ball)
	num_soft_ball_points = soft_ball.num_points

func _process(delta: float) -> void:
	var friction : Vector2 = air_friction_constant * soft_ball.get_center_velocity()
	#terrain.position += Vector2(-terrain_speed, -1)
	
	if Input.is_action_just_pressed("boost"):
		boost = Vector2(10000.0, 10.0)
	
	dive = AccelInput.dive
	soft_ball.apply_force(soft_ball.get_gravity() * dive * num_soft_ball_points + Vector2(ball_horizontal_force, 0.0) + friction + boost)

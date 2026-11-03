extends Node2D

const SKY_COLOR := Color("#3a3166")
const PIXELS_PER_METER : float = 100.0
const air_friction_constant : float = 0.0000005
const terrain_rotation_angle : float = 20.0
const boost_vector = Vector2(10000.0, 100.0)

const COIN_SCENE := preload("res://collectabels/coin.gd")

@onready var label = $CanvasLayer/Label

const SOFT_BALL_SCENE := preload("res://soft_body_sim/soft_ball.tscn")
var soft_ball : SoftBall
var num_soft_ball_points : int
var ball_driving_force : Vector2

var dive : float

var terrain : Terrain

func  _ready() -> void:
	RenderingServer.set_default_clear_color(SKY_COLOR)
	dive = AccelInput.dive
	ball_driving_force = Vector2(-500.0, 0.0)
	
	add_child(StarField.new()) # stars first since they are the furtherest back in thr background
	var scenery = Scenery.new()
	scenery.rotation_degrees = terrain_rotation_angle
	add_child(scenery)   # Scenery includes all background hills, must be before terrain
	
	terrain = Terrain.new()
	terrain.rotation_degrees = terrain_rotation_angle
	terrain.position += Vector2(0.0, 100.0)
	#terrain.generate_coins = true
	add_child(terrain)
	
	soft_ball = SOFT_BALL_SCENE.instantiate() as SoftBall
	soft_ball.spawn_position = Vector2(500.0, 300.0)
	add_child(soft_ball)
	num_soft_ball_points = soft_ball.num_points

var total_force
var friction

func _process(delta: float) -> void:
	friction = soft_ball.get_center_velocity() * air_friction_constant
	dive = AccelInput.dive
	total_force = friction + soft_ball.get_gravity() * dive * num_soft_ball_points + ball_driving_force
	
	if Input.is_action_just_pressed("boost"):
		total_force += boost_vector
	
	soft_ball.apply_force(total_force)
	
	label.text = "coins collected: " + str(PlayerInventory.num_coins_collected)
	

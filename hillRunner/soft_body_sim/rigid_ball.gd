extends RigidBody2D

@export var radius = 30.0

func _ready() -> void:
	$CollisionShape2D.shape.radius = radius

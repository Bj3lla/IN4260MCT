class_name SoftPoint
extends RigidBody2D
## Responsibility: one point of the soft body: a small ice-like circle.
## Scene soft_point.tscn: a RigidBody2D root with one child CollisionShape2D.

@export var radius := 10.0


func _ready() -> void:
	var shape := CircleShape2D.new()   # own shape per point: no shared-resource surprises
	shape.radius = radius
	$CollisionShape2D.shape = shape

	physics_material_override = Ice.material()
	can_sleep = false
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	contact_monitor = true
	max_contacts_reported = 2

class_name Ice
extends RefCounted
## One shared slippery physics material (no friction, no bounce) used by the
## terrain, the rigid ball and every soft-body point.

static var _material: PhysicsMaterial


static func material() -> PhysicsMaterial:
	if _material == null:
		_material = PhysicsMaterial.new()
		_material.friction = 0.0
		_material.bounce = 0.0
	return _material

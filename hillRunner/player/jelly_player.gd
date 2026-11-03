class_name JellyPlayer
extends RigidPlayer
## Responsibility: the hybrid ball. Moves like RigidPlayer (same body, same
## ice integrator, scaled by speed_scale), but is drawn like the soft ball: a wobbly outline
## that flattens against the ground, squashes on landings, stretches with
## speed and is tinted by the dive colour.
##
## The wobble only affects the look. Each outline vertex has a radial offset
## that acts like a damped spring, so nothing here touches the physics body.

## How fast this ball moves compared to the rigid ball (1 = same). It follows
## the same arcs over the hills, just slower and a bit floatier.
@export_range(0.3, 1.5, 0.05) var speed_scale := 0.8

@export_group("Jelly look")
@export var visual_radius := 30.0      ## outline size at rest; bigger than `radius` gives a flat patch on the ground
@export var num_vertices := 32
@export var stiffness := 200.0         ## pulls each vertex back to its rest radius
@export var damping := 6.0             ## lower = wobbles longer
@export var smoothing := 300.0         ## pulls vertices toward their neighbours (keeps the outline round)
@export var pressure := 400.0          ## pushes outward when squashed, so it bulges instead of shrinking
@export var landing_squash := 0.14     ## top dip per px/s of impact speed
@export var max_impact := 1200.0       ## impact speed cap (px/s) so huge drops don't fold the outline
@export var speed_stretch := 0.12      ## stretch along velocity at max speed (fraction of radius)
@export var outline_color := Color.WHITE
@export var outline_width := 3.0

var _dirs: PackedVector2Array = []     ## unit direction of each vertex
var _offset: PackedFloat32Array = []   ## radial offset from visual_radius
var _offset_vel: PackedFloat32Array = []
var _was_on_ground := false
var _prev_velocity := Vector2.ZERO
var _color := COLOR_REST


func _ready() -> void:
	# Own copy of the tuning so slowing this ball never affects the other balls.
	# Speed on the hills grows with sqrt(gravity), so gravity and thrust scale by
	# speed_scale² and speed limits by speed_scale: same paths, played slower.
	var accel_scale := speed_scale * speed_scale
	tuning = tuning.duplicate()
	tuning.start_speed *= speed_scale
	tuning.min_speed *= speed_scale
	tuning.max_speed *= speed_scale
	tuning.min_launch_vy *= speed_scale
	gravity *= accel_scale
	slope_thrust_strength *= accel_scale
	super()
	for i in num_vertices:
		_dirs.append(Vector2.RIGHT.rotated(TAU / num_vertices * i))
	_offset.resize(num_vertices)
	_offset_vel.resize(num_vertices)


func _physics_process(delta: float) -> void:
	super(delta)
	var n := ground_normal

	# Landing: kick the top of the outline down, proportional to impact speed.
	if on_ground and not _was_on_ground:
		var impact := minf(maxf(-_prev_velocity.dot(n), 0.0), max_impact)
		for i in num_vertices:
			_offset_vel[i] -= impact * landing_squash * maxf(_dirs[i].dot(n), 0.0)
	_was_on_ground = on_ground
	_prev_velocity = linear_velocity

	_step_wobble(delta)
	if on_ground:
		_flatten_against(n)
	_color = dive_color(AccelInput.dive)


func _step_wobble(dt: float) -> void:
	var speed := linear_velocity.length()
	var heading := linear_velocity / speed if speed > 1.0 else Vector2.RIGHT
	var stretch := visual_radius * speed_stretch * clampf(speed / tuning.max_speed, 0.0, 1.0)

	# Area deficit relative to the rest circle (r² is proportional to the area of each slice).
	var area := 0.0
	for r in _offset:
		area += (visual_radius + r) * (visual_radius + r)
	var deficit := 1.0 - area / (visual_radius * visual_radius * num_vertices)

	for i in num_vertices:
		var r := _offset[i]
		# cos(2θ) to the velocity: longer front and back, thinner top and bottom.
		var along := _dirs[i].dot(heading)
		var target := stretch * (2.0 * along * along - 1.0)
		var neighbours := _offset[posmod(i - 1, num_vertices)] + _offset[(i + 1) % num_vertices] - 2.0 * r
		var accel := (stiffness * (target - r) - damping * _offset_vel[i]
				+ smoothing * neighbours + pressure * deficit * visual_radius)
		_offset_vel[i] += accel * dt   # semi-implicit Euler: velocity first
	for i in num_vertices:
		_offset[i] += _offset_vel[i] * dt


## The ground sits `radius` (the collision radius) below the centre. Any vertex
## past that line is pushed back onto it, giving a flat patch like the soft ball.
func _flatten_against(n: Vector2) -> void:
	for i in num_vertices:
		var down := -_dirs[i].dot(n)
		if down < 0.1:
			continue
		var limit := radius / down - visual_radius
		if _offset[i] > limit:
			_offset[i] = limit
			_offset_vel[i] = minf(_offset_vel[i], 0.0)


func _draw() -> void:
	var points := PackedVector2Array()
	for i in num_vertices:
		points.append(_dirs[i] * (visual_radius + _offset[i]))

	# Stretch the texture over the current shape, like SoftBall does, so the face squishes too.
	var bounds := Rect2(points[0], Vector2.ZERO)
	for p in points:
		bounds = bounds.expand(p)
	var uvs := PackedVector2Array()
	for p in points:
		uvs.append((p - bounds.position) / bounds.size)

	draw_polygon(points, PackedColorArray([_color]), uvs, CHARACTER_TEXTURE)
	points.append(points[0])
	draw_polyline(points, outline_color, outline_width, true)

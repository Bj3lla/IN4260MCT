extends RigidBody2D
## The player. Diving (device push / spacebar) multiplies gravity.
## Dive on downslopes to gain speed, release on upslopes to launch — same as Tiny Wings.
##
## Movement is integrated by hand (custom_integrator) so the ground feels like ice:
## sliding never loses speed to friction or collisions, only gravity changes it.

signal landed(kind: String, change: float)

@export var radius := 26.0
@export var base_gravity := 1.0     ## gravity scale while touching the ground
@export var air_gravity := 0.8      ## gravity scale while flying (lower = floatier)
@export var dive_gravity := 4.0     ## extra gravity scale at full dive
@export var launch_boost := 1.2     ## upward speed multiplier when leaving an upslope without diving
@export var min_launch_vy := 150.0  ## only boost real launches, not small bumps
@export var landing_bonus := 0.15   ## max speed gained when landing on a steep downslope (+25%)
@export var landing_penalty := 0.4  ## max speed lost when landing on a steep upslope (-40%)
@export var steep_slope := 0.6      ## slope (tangent.y) that counts as "fully steep"
@export var min_air_time := 0.12    ## seconds airborne before a touchdown counts as a landing
@export var min_speed := 180.0      ## never stall completely
@export var max_speed := 1500.0
@export var slope_thrust := 1200.0  ## px/s² pushed along the hill at full dive on a steep downslope
@export var uphill_brake := 1.3     ## uphill braking vs downhill thrust (>1 so holding dive all the time doesn't pay)
@export var air_dive_gravity := 2.5 ## extra gravity in the air while diving (land sooner)

var on_ground := false
var spin := 0.0
var air_time := 0.0
var _v := Vector2(250, 0)
var _g := 980.0


func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	var mat := PhysicsMaterial.new()
	mat.friction = 0.0
	mat.bounce = 0.0
	physics_material_override = mat

	_g = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
	mass = 1.0
	lock_rotation = true
	can_sleep = false
	custom_integrator = true
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	contact_monitor = true
	max_contacts_reported = 4
	linear_velocity = _v


func _physics_process(delta: float) -> void:
	spin += linear_velocity.x / radius * delta
	queue_redraw()



#
#func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	#var dt := state.step
	#var dive := AccelInput.dive
	#var v := _v
#
	## Average contact normal, pointing up out of the ground.
	#var n := Vector2.ZERO
	#for i in state.get_contact_count():
		#n += state.get_contact_local_normal(i)
	#on_ground = n.length_squared() > 0.0001
	#if on_ground:
		#n = n.normalized()
		#if n.y > 0:
			#n = -n
#
	#if on_ground:
		#var t := Vector2(-n.y, n.x)       # tangent along the hill
		#if t.x < 0:
			#t = -t
		#var speed := v.length()
		#if air_time >= min_air_time:
			#speed = _landing_speed(speed, t.y)
		#air_time = 0.0
		## Ice: keep all speed, only the slope's share of gravity changes it.
		#var g := Vector2(0, _g * (base_gravity + dive_gravity * dive))
		#speed += g.dot(t) * dt
		#speed = clampf(speed, min_speed, max_speed)
		#v = t * speed
	#else:
		#var was := air_time
		#air_time += dt
		## Takeoff boost once we're clearly airborne and still rising.
		#if was < 0.05 and air_time >= 0.05 and -v.y > min_launch_vy and dive < 0.3:
			#v.y *= launch_boost
		#v.y += _g * (air_gravity + dive_gravity * dive) * dt
		#v.x = maxf(v.x, min_speed)
		#v = v.limit_length(max_speed)
#
	#_v = v
	#state.linear_velocity = v
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var dt := state.step
	var dive := AccelInput.dive
	var v := _v

	# Average contact normal, pointing up out of the ground.
	var n := Vector2.ZERO
	for i in state.get_contact_count():
		n += state.get_contact_local_normal(i)
	on_ground = n.length_squared() > 0.0001
	if on_ground:
		n = n.normalized()
		if n.y > 0:
			n = -n

	if on_ground:
		var t := Vector2(-n.y, n.x)       # tangent along the hill
		if t.x < 0:
			t = -t
		var speed := v.length()
		if air_time >= min_air_time:
			speed = _landing_speed(speed, t.y)
		air_time = 0.0
		# Ice: keep all speed; only gravity along the slope and diving change it.
		var g := Vector2(0, _g * base_gravity)
		var slope := clampf(t.y / steep_slope, -1.0, 1.0)   # +1 steep down, -1 steep up
		var thrust := dive * slope_thrust * slope
		if slope < 0.0:
			thrust *= uphill_brake
		speed += (g.dot(t) + thrust) * dt
		speed = clampf(speed, min_speed, max_speed)
		v = t * speed
	else:
		var was := air_time
		air_time += dt
		# Takeoff boost once we're clearly airborne and still rising.
		if was < 0.05 and air_time >= 0.05 and -v.y > min_launch_vy and dive < 0.3:
			v.y *= launch_boost
		v.y += _g * (air_gravity + air_dive_gravity * dive) * dt
		v.x = maxf(v.x, min_speed)
		v = v.limit_length(max_speed)

	_v = v
	state.linear_velocity = v


func _landing_speed(speed: float, slope: float) -> float:
	# slope > 0 means the hill goes down to the right.
	var k := clampf(absf(slope) / steep_slope, 0.0, 1.0)
	var change := 0.0
	var kind := "flat"
	if slope > 0.05:
		change = landing_bonus * k
		kind = "great" if k > 0.6 else "good"
	elif slope < -0.05:
		change = -landing_penalty * k
		kind = "bad"
	landed.emit(kind, change)
	return speed * (1.0 + change)


func _draw() -> void:
	var d := AccelInput.dive
	var body_col := Color("#3b4a6b").lerp(Color("#d94a4a"), d)
	draw_circle(Vector2.ZERO, radius, body_col)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color.WHITE, 3.0, true)
	var dir := Vector2.from_angle(spin)
	draw_line(-dir * radius * 0.8, dir * radius * 0.8, Color(1, 1, 1, 0.8), 4.0, true)
	draw_circle(dir.orthogonal() * radius * 0.45, 4.0, Color.WHITE)

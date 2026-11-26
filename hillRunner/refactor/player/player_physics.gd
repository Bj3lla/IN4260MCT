class_name PlayerPhysics
extends Node2D
## What a ball IS to the rest of the game (position, linear_velocity,
## on_ground, `landed` signal), its tuning values, and the rules both physics
## models share: ground tangent, slope thrust, landing judgement, launch timing.
## Subclasses (RigidBall, SoftBall) only decide how those results become motion.

signal landed(kind: String, change: float)

const CHARACTER_TEXTURE: Texture2D = preload("res://refactor/visuals/Ball character.svg")
const COLOR_REST := Color("#EDE3C9")
const COLOR_DIVE := Color("#FF87B6")
const COLOR_FLOAT := Color("#60F4EA")
const COLOR_BOOST := Color("#FBB14D")
const GREAT_LANDING := 0.6   ## slope fraction (0..1) from which a landing is "great"
const COLOR_DEADZONE := 0.05 

@export var start_speed := 250.0
@export var min_speed := 180.0           ## never stall completely
@export var max_speed := 1800.0
@export var boost_accel := 2000.0         ## forward acceleration while boosting

@export_group("Air")
@export var air_gravity := 0.8           ## gravity scale while flying (lower = floatier)
@export var air_dive_gravity := 2.5      ## extra gravity in the air while diving (land sooner)
@export var launch_boost := 1.2          ## upward speed multiplier when leaving an upslope
@export var min_launch_vy := 150.0       ## only boost real launches, not small bumps
@export var launch_delay := 0.05         ## seconds airborne before the launch boost applies
@export var launch_max_dive := 0.3       ## no launch boost while diving harder than this

@export_group("Float")
@export_range(0.0, 0.95) var max_float_lift := 0.7  ## share of air gravity cancelled at dive = -1. Keep < 1 or it never falls
@export var float_rise_drag := 3.0                  ## how fast upward speed bleeds off while floating
@export var float_fall_speed := 100.0  ## gentle fall speed (px/s) that floating brakes a fast fall down to
@export var float_catch := 6.0         ## how hard a fast fall is braked toward float_fall_speed (per second)

@export_group("Ground")
@export var steep_slope := 0.6           ## slope (tangent.y) that counts as "fully steep"
@export var uphill_brake := 1.3          ## uphill braking vs downhill thrust (>1: holding dive forever doesn't pay)

@export_group("Landing")
@export var landing_bonus := 0.3        ## max speed gained on a steep downslope (+15%)
@export var landing_penalty := 0.3       ## max speed lost on a steep upslope (-40%)
@export var min_air_time := 0.12         ## seconds airborne before a touchdown counts
@export var flat_slope := 0.05           ## slopes flatter than this are neither good nor bad

var linear_velocity := Vector2.ZERO   ## average velocity, kept up to date by the subclass
var on_ground := false
var boosting := false                 ## set by Player while boost is held and the bar isn't empty
var float_strength := 1.0 
var air_time := 0.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)


## Slippery physics material (no friction, no bounce) for the balls.
## The track can use it too: PlayerPhysics.ice()
static func ice() -> PhysicsMaterial:
	var material := PhysicsMaterial.new()
	material.friction = 0.0   # bounce is already 0 by default
	return material


func color(dive: float) -> Color:
	if boosting:
		return COLOR_BOOST
	if absf(dive) < COLOR_DEADZONE:
		return COLOR_REST
	return COLOR_REST.lerp(COLOR_DIVE if dive > 0.0 else COLOR_FLOAT, clampf(absf(dive), 0.0, 1.0))


## Normalised ground normal pointing up, from a sum of contact normals.
static func up_normal(summed: Vector2) -> Vector2:
	var n := summed.normalized()
	return -n if n.y > 0.0 else n


## Unit tangent along the ground, pointing right (t.y > 0 = downhill).
static func tangent_of(normal: Vector2) -> Vector2:
	var t := Vector2(-normal.y, normal.x)
	return -t if t.x < 0.0 else t


## Extra acceleration along the hill from diving. Positive on downslopes,
## negative (braking) on upslopes, and never pushes backwards below min_speed.
func slope_thrust(tangent: Vector2, dive: float, speed: float, strength: float) -> float:
	dive = maxf(dive, 0.0) #floating does nothing on the ground
	var slope := clampf(tangent.y / steep_slope, -1.0, 1.0)
	var thrust := dive * strength * slope
	if slope < 0.0:
		thrust *= uphill_brake if speed > min_speed else 0.0
	return thrust


## Call every physics step while touching the ground. Returns the speed change
## (fraction, e.g. +0.1) if this touchdown counts as a landing, else 0.
func touch_down(tangent: Vector2) -> float:
	var change := 0.0
	if air_time >= min_air_time:
		change = _judge_landing(tangent.y)
	air_time = 0.0
	return change


## Call every physics step while airborne. Returns true on the one step where
## the launch boost should be applied.
func advance_air(dt: float, velocity: Vector2, dive: float) -> bool:
	var was := air_time
	air_time += dt
	return (was < launch_delay and air_time >= launch_delay
			and -velocity.y > min_launch_vy and dive < launch_max_dive)


## Vertical acceleration in the air (px/s², +y = down) for the current dive.
## dive > 0: heavier, lands sooner. dive < 0: floaty, but gravity never flips.
func air_accel_y(dive: float, vy: float) -> float:
	var g := gravity * air_gravity
	if dive >= 0.0:
		return g + gravity * air_dive_gravity * dive

	var f := minf(-dive, 1.0) * float_strength     # 0..1 float amount
	var accel := g * (1.0 - max_float_lift * f)    # weaker gravity, still positive
	if vy < 0.0:
		accel -= vy * float_rise_drag * f          # rising: bleed off upward speed
	elif vy > float_fall_speed:
		accel -= (vy - float_fall_speed) * float_catch * f   # falling fast: catch it
	return accel


func _judge_landing(slope: float) -> float:
	var k := clampf(absf(slope) / steep_slope, 0.0, 1.0)
	var change := 0.0
	var kind := "flat"
	if slope > flat_slope:
		change = landing_bonus * k
		kind = "great" if k > GREAT_LANDING else "good"
	elif slope < -flat_slope:
		change = -landing_penalty * k
		kind = "bad"
	landed.emit(kind, change)
	return change

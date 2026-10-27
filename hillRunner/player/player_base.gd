class_name PlayerBase
extends Node2D
## Responsibility: what a ball IS to the rest of the game (position,
## linear_velocity, on_ground, `landed` signal) plus the rules both physics
## models share: ground tangent, slope thrust, landing judgement, launch timing.
## Subclasses only decide how those results become motion.

signal landed(kind: String, change: float)

const COLOR_REST := Color("#3b4a6b")
const COLOR_DIVE := Color("#d94a4a")
const GREAT_LANDING := 0.6   ## slope fraction (0..1) from which a landing is "great"

@export var tuning := PlayerTuning.new()

var linear_velocity := Vector2.ZERO   ## average velocity, kept up to date by the subclass
var on_ground := false
var air_time := 0.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)


static func dive_color(dive: float) -> Color:
	return COLOR_REST.lerp(COLOR_DIVE, dive)


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
	var slope := clampf(tangent.y / tuning.steep_slope, -1.0, 1.0)
	var thrust := dive * strength * slope
	if slope < 0.0:
		thrust *= tuning.uphill_brake if speed > tuning.min_speed else 0.0
	return thrust


## Call every physics step while touching the ground. Returns the speed change
## (fraction, e.g. +0.1) if this touchdown counts as a landing, else 0.
func touch_down(tangent: Vector2) -> float:
	var change := 0.0
	if air_time >= tuning.min_air_time:
		change = _judge_landing(tangent.y)
	air_time = 0.0
	return change


## Call every physics step while airborne. Returns true on the one step where
## the launch boost should be applied.
func advance_air(dt: float, velocity: Vector2, dive: float) -> bool:
	var was := air_time
	air_time += dt
	return (was < tuning.launch_delay and air_time >= tuning.launch_delay
			and -velocity.y > tuning.min_launch_vy and dive < tuning.launch_max_dive)


func _judge_landing(slope: float) -> float:
	var k := clampf(absf(slope) / tuning.steep_slope, 0.0, 1.0)
	var change := 0.0
	var kind := "flat"
	if slope > tuning.flat_slope:
		change = tuning.landing_bonus * k
		kind = "great" if k > GREAT_LANDING else "good"
	elif slope < -tuning.flat_slope:
		change = -tuning.landing_penalty * k
		kind = "bad"
	landed.emit(kind, change)
	return change

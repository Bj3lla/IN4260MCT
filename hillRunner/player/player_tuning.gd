class_name PlayerTuning
extends Resource
## Responsibility: shared tuning for soft ball and rigid ball, so they play by the
## same rules. Create a .tres from this to tweak in the inspector.

@export var start_speed := 250.0
@export var min_speed := 180.0           ## never stall completely
@export var max_speed := 1500.0

@export_group("Air")
@export var air_gravity := 0.8           ## gravity scale while flying (lower = floatier)
@export var air_dive_gravity := 2.5      ## extra gravity in the air while diving (land sooner)
@export var launch_boost := 1.2          ## upward speed multiplier when leaving an upslope
@export var min_launch_vy := 150.0       ## only boost real launches, not small bumps
@export var launch_delay := 0.05         ## seconds airborne before the launch boost applies
@export var launch_max_dive := 0.3       ## no launch boost while diving harder than this

@export_group("Ground")
@export var steep_slope := 0.6           ## slope (tangent.y) that counts as "fully steep"
@export var uphill_brake := 1.3          ## uphill braking vs downhill thrust (>1: holding dive forever doesn't pay)

@export_group("Landing")
@export var landing_bonus := 0.15        ## max speed gained on a steep downslope (+15%)
@export var landing_penalty := 0.4       ## max speed lost on a steep upslope (-40%)
@export var min_air_time := 0.12         ## seconds airborne before a touchdown counts
@export var flat_slope := 0.05           ## slopes flatter than this are neither good nor bad

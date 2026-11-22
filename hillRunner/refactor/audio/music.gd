extends AudioStreamPlayer

@export var base_bpm: float = 90.0 #important! Must match the audio files BPM in the inspector
@export var smoothing_speed: float = 3.0 #how fast music adapts to heart rate, higher = faster

@onready var _shift := AudioServer.get_bus_effect(AudioServer.get_bus_index(bus), 0) as AudioEffectPitchShift


func _process(delta: float) -> void:
	var target_pitch := 1.0 #normal speed until real heart rate data arrives
	if InputProcessing.heart_rate > 30.0:
		target_pitch = clampf(InputProcessing.heart_rate / base_bpm, 0.25, 2.5)
		
	pitch_scale = lerpf(pitch_scale, target_pitch, smoothing_speed * delta) #smooth glide to new BPM so big jumps in sensordata don't sound awful
	_shift.pitch_scale = 1.0 / pitch_scale #undo the key change, but keep the tempo change

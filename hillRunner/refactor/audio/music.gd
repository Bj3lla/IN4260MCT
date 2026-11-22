extends AudioStreamPlayer2D

@export var base_bpm: float = 90.0 #important! Must match the audio files BPM in the inspector
@export var smoothing_speed: float = 3.0 #how fast music adapts to heart rate, higher = faster


var _target_pitch: float = 1.0

func _ready() -> void:
	InputProcessing.heart_rate_change.connect(_on_heart_rate_change) #connect to global InputProcessing autoload signal
	
	if InputProcessing.heart_rate > 30.0: # sync to heart rate on startup
		_on_heart_rate_change(InputProcessing.heart_rate)
		pitch_scale = _target_pitch

func _process(delta: float) -> void:
	pitch_scale = lerpf(pitch_scale, _target_pitch, smoothing_speed * delta) #smooth glide to new BPM so big jumps in sensordata don't sound awful
	
func _on_heart_rate_change(new_bpm: float) -> void: # connect input_processing's heartrate signal to this function
	_target_pitch = clampf(new_bpm / base_bpm, 0.5, 2.5)

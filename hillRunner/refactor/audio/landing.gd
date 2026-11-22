extends AudioStreamPlayer

@export var player: Player
@export var great_landing: AudioStream #linked to sample in inspector
@export var bad_landing: AudioStream #linked to sample in inspector

func _ready() -> void:
	player.landed.connect(_on_landed)
	
func _on_landed(kind: String, _change: float) -> void:
	match kind:
		"great": stream = great_landing
		"bad": stream = bad_landing
		_: return 
	play()

extends Node2D

@onready var label : Label = $Label
@onready var dive : float = AccelInput.dive

func _process(delta: float) -> void:
	dive = AccelInput.dive
	label.text = str(dive)

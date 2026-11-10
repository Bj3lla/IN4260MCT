class_name World
extends Node2D

func _ready() -> void:
	var terrain := Terrain.new()
	add_child(terrain)

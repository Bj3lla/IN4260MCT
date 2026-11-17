class_name World
extends Node2D
#builds world by using Track, Scenery and StarField
const SKY_COLOR := Color("#3a3166")
var track: Track

func _ready() -> void:
	RenderingServer.set_default_clear_color(SKY_COLOR)
	add_child(StarField.new())
	add_child(Scenery.new()) 
	
	track = Track.new()
	add_child(track)
	

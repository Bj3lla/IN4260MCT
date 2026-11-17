class_name World
extends Node2D
#builds world by using Track, Scenery and StarField

var RigidBallScene = preload("res://refactor/player/bodies/rigid_ball/RigidBall.tscn")

func _ready() -> void:
	add_child(Scenery.new()) 
	add_child(StarField.new())
	
	var track := Track.new()
	add_child(track)
	
	add_child(RigidBallScene.instantiate())

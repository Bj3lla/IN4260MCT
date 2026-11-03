extends Node

var num_coins_collected

func _ready() -> void:
	num_coins_collected = 0

func collect_coin() -> void:
	num_coins_collected += 1

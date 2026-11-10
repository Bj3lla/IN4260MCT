extends Node

# provides functions for non-engine player-physics calculations
# - air friction
# - input based force
# - total non-gravity force

var player : Player

func set_player(_player : Player) -> void:
	player = _player

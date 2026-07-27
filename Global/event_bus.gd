extends Node

signal player_body_replaced(old_body: Node2D, new_body: Node2D)

func emit_player_body_replaced(old_body: Node2D, new_body: Node2D) -> void:
	if old_body == null or new_body == null:
		return
	player_body_replaced.emit(old_body, new_body)

extends Node

var enabled := false

func toggle() -> bool:
	enabled = not enabled
	return enabled

func is_enabled() -> bool:
	return enabled

func applies_to(character: CharacterBody2D) -> bool:
	if not enabled or character == null:
		return false
	if not is_instance_valid(character):
		return false
	if not character.has_method("is_player_character"):
		return false
	return bool(character.call("is_player_character"))

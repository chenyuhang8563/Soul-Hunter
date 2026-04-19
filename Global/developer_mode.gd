extends Node

signal mode_changed(enabled)

var enabled := false

func toggle() -> bool:
	return set_enabled(not enabled)

func set_enabled(value: bool) -> bool:
	if enabled == value:
		return enabled
	enabled = value
	mode_changed.emit(enabled)
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

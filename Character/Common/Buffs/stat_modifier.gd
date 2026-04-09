extends "res://Character/Common/modifier.gd"
class_name StatModifier

func duplicate_modifier() -> StatModifier:
	return StatModifier.new(stat_id, value, mode, priority)

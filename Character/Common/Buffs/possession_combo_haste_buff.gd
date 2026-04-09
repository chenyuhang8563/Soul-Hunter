extends "res://Character/Common/Buffs/buff_effect.gd"
class_name PossessionComboHasteBuff

const StatModifierScript := preload("res://Character/Common/Buffs/stat_modifier.gd")

var move_speed_bonus := 0.15
var attack_cooldown_bonus := -0.15

func _init() -> void:
	buff_id = &"possession_combo_haste"
	stack_key = &"possession_combo_haste"
	display_name = "Possession Combo Haste"
	stack_policy = StackPolicy.RESET_DURATION
	max_stacks = 1
	setup_duration(4.0)

func build_modifiers() -> Array:
	return [
		StatModifierScript.new(&"move_speed", move_speed_bonus, StatModifierScript.Mode.MULTIPLY, 100),
		StatModifierScript.new(&"attack_cooldown", attack_cooldown_bonus, StatModifierScript.Mode.MULTIPLY, 100),
	]

func on_refreshed(incoming) -> void:
	if incoming == null:
		return
	move_speed_bonus = float(incoming.move_speed_bonus)
	attack_cooldown_bonus = float(incoming.attack_cooldown_bonus)
	mark_modifiers_dirty()

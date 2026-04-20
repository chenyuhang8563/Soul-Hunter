extends "res://Character/Common/Buffs/buff_effect.gd"
class_name WerebearKnockbackResistBuff

const StatModifierScript := preload("res://Character/Common/Buffs/stat_modifier.gd")

var knockback_taken_multiplier_bonus := -0.5

func _init() -> void:
	buff_id = &"werebear_knockback_resist"
	stack_key = &"werebear_knockback_resist"
	display_name = "Werebear Knockback Resist"
	stack_policy = StackPolicy.RESET_DURATION
	max_stacks = 1
	setup_duration(0.0, true)

func build_modifiers() -> Array:
	return [
		StatModifierScript.new(&"knockback_taken_multiplier", knockback_taken_multiplier_bonus, StatModifierScript.Mode.MULTIPLY, 100),
	]

func on_refreshed(incoming) -> void:
	if incoming == null:
		return
	knockback_taken_multiplier_bonus = float(incoming.knockback_taken_multiplier_bonus)
	mark_modifiers_dirty()

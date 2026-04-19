extends "res://Character/Common/Buffs/buff_effect.gd"
class_name WerebearEnrageBuff

const StatModifierScript := preload("res://Character/Common/Buffs/stat_modifier.gd")

var move_speed_bonus := 0.25
var attack_speed_bonus := 0.25
var attack_damage_bonus := 0.25

func _init() -> void:
	buff_id = &"werebear_enrage"
	stack_key = &"werebear_enrage"
	display_name = "Werebear Enrage"
	stack_policy = StackPolicy.RESET_DURATION
	max_stacks = 1
	setup_duration(0.0, true)

func build_modifiers() -> Array:
	return [
		StatModifierScript.new(&"move_speed", move_speed_bonus, StatModifierScript.Mode.MULTIPLY, 100),
		StatModifierScript.new(&"attack_speed_multiplier", attack_speed_bonus, StatModifierScript.Mode.MULTIPLY, 100),
		StatModifierScript.new(&"light_attack_damage", attack_damage_bonus, StatModifierScript.Mode.MULTIPLY, 100),
		StatModifierScript.new(&"hard_attack_damage", attack_damage_bonus, StatModifierScript.Mode.MULTIPLY, 100),
		StatModifierScript.new(&"ultimate_attack", attack_damage_bonus, StatModifierScript.Mode.MULTIPLY, 100),
	]

func on_refreshed(incoming) -> void:
	if incoming == null:
		return
	move_speed_bonus = float(incoming.move_speed_bonus)
	attack_speed_bonus = float(incoming.attack_speed_bonus)
	attack_damage_bonus = float(incoming.attack_damage_bonus)
	mark_modifiers_dirty()

extends "res://Character/Common/Buffs/buff_effect.gd"
class_name BerserkBuff

const StatModifierScript := preload("res://Character/Common/Buffs/stat_modifier.gd")
const BuffIconScene := preload("res://Scenes/UI/buff_icon.tscn")

var attack_multiplier_bonus := 0.2

func _init() -> void:
	buff_id = &"berserk"
	stack_key = &"berserk"
	display_name = "Berserk"
	stack_policy = StackPolicy.RESET_DURATION
	max_stacks = 1
	setup_duration(10.0)

func build_modifiers() -> Array:
	return [
		StatModifierScript.new(&"light_attack_damage", attack_multiplier_bonus, StatModifierScript.Mode.MULTIPLY, 100),
		StatModifierScript.new(&"hard_attack_damage", attack_multiplier_bonus, StatModifierScript.Mode.MULTIPLY, 100),
		StatModifierScript.new(&"ultimate_attack", attack_multiplier_bonus, StatModifierScript.Mode.MULTIPLY, 100),
	]

func on_refreshed(incoming) -> void:
	if incoming == null:
		return
	attack_multiplier_bonus = float(incoming.attack_multiplier_bonus)
	mark_modifiers_dirty()

func create_icon_instance() -> Node2D:
	return BuffIconScene.instantiate() as Node2D

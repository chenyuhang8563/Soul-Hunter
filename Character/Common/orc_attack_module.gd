extends "res://Character/Common/simple_melee_attack_module.gd"
class_name OrcAttackModule

func _init() -> void:
	configure({
		"light_attack_duration": 0.60,
		"hard_attack_duration": 0.60,
		"light_attack_hit_delay": 0.40,
		"hard_attack_hit_delay": 0.45,
		"melee_attack_range": 42.0,
		"light_attack_probability": 0.6,
	})

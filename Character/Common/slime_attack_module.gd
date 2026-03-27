extends "res://Character/Common/simple_melee_attack_module.gd"
class_name SlimeAttackModule

func _init() -> void:
	configure({
		"light_attack_duration": 0.60,
		"hard_attack_duration": 1.20,
		"light_attack_hit_delay": 0.30,
		"hard_attack_hit_delay": 0.60,
		"melee_attack_range": 35.0,
		"light_attack_probability": 0.6,
	})

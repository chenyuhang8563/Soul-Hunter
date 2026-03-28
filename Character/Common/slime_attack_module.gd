extends "res://Character/Common/simple_melee_attack_module.gd"
class_name SlimeAttackModule

const SlowedBuffScript := preload("res://Character/Common/Buffs/slowed_buff.gd")

func _init() -> void:
	configure({
		"light_attack_duration": 0.60,
		"hard_attack_duration": 1.20,
		"light_attack_hit_delay": 0.30,
		"hard_attack_hit_delay": 0.60,
		"melee_attack_range": 35.0,
		"light_attack_probability": 0.6,
	})

func _apply_damage_to_target(target: Node2D, damage: float) -> void:
	super._apply_damage_to_target(target, damage)
	if target != null and target.has_method("add_buff"):
		target.add_buff(SlowedBuffScript.new())

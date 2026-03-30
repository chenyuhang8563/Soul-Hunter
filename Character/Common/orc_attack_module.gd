extends "res://Character/Common/simple_melee_attack_module.gd"
class_name OrcAttackModule

const BerserkBuffScript := preload("res://Character/Common/Buffs/berserk_buff.gd")

func _init() -> void:
	configure({
		"light_attack_duration": 0.60,
		"hard_attack_duration": 0.60,
		"light_attack_hit_delay": 0.40,
		"hard_attack_hit_delay": 0.45,
		"melee_attack_range": 42.0,
		"light_attack_probability": 0.6,
	})

func _apply_damage_to_target(target: Node2D, damage: float) -> bool:
	var did_apply := super._apply_damage_to_target(target, damage)
	if not did_apply:
		return false
	if owner == null or current_attack != "hard_attack":
		return true
	if owner.has_method("add_buff"):
		owner.add_buff(BerserkBuffScript.new())
	return true

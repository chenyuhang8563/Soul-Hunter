extends Resource
class_name CharacterStats

@export var max_health := 500.0
@export var light_attack_damage := 30.0
@export var hard_attack_damage := 50.0
@export var ultimate_attack := 20.0

func get_value(stat_id: StringName, fallback: float = 0.0) -> float:
	match stat_id:
		&"max_health":
			return max_health
		&"light_attack_damage":
			return light_attack_damage
		&"hard_attack_damage":
			return hard_attack_damage
		&"ultimate_attack":
			return ultimate_attack
		_:
			return fallback

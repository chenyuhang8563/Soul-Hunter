extends Resource
class_name CharacterStats

@export var max_health := 450.0
@export var move_speed := 100.0
@export var attack_cooldown := 0.22
@export var attack_speed_multiplier := 1.0
@export var light_attack_damage := 25.0
@export var hard_attack_damage := 45.0
@export var ultimate_attack := 20.0
@export var knockback_taken_multiplier := 1.0
@export var defense := 0.0
@export var crit_chance := 5.0

func get_value(stat_id: StringName, fallback: float = 0.0) -> float:
	match stat_id:
		&"max_health":
			return max_health
		&"move_speed":
			return move_speed
		&"attack_cooldown":
			return attack_cooldown
		&"attack_speed_multiplier":
			return attack_speed_multiplier
		&"light_attack_damage":
			return light_attack_damage
		&"hard_attack_damage":
			return hard_attack_damage
		&"ultimate_attack":
			return ultimate_attack
		&"knockback_taken_multiplier":
			return knockback_taken_multiplier
		&"defense":
			return defense
		&"crit_chance":
			return crit_chance
		_:
			return fallback

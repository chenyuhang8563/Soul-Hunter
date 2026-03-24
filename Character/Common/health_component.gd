extends RefCounted
class_name HealthComponent

signal health_changed(current_health: float, max_health: float)
signal damaged(amount: float, current_health: float, max_health: float, source: CharacterBody2D)
signal died(source: CharacterBody2D)

var max_health := 100.0
var current_health := 100.0

func setup(initial_max_health: float) -> void:
	max_health = maxf(1.0, initial_max_health)
	current_health = max_health
	health_changed.emit(current_health, max_health)

func apply_damage(amount: float, source: CharacterBody2D = null) -> void:
	if amount <= 0.0 or not is_alive():
		return
	current_health = maxf(0.0, current_health - amount)
	damaged.emit(amount, current_health, max_health, source)
	health_changed.emit(current_health, max_health)
	if current_health == 0.0:
		died.emit(source)

func heal(amount: float) -> void:
	if amount <= 0.0 or not is_alive():
		return
	current_health = minf(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

func is_alive() -> bool:
	return current_health > 0.0

func get_hp_ratio() -> float:
	return current_health / max_health

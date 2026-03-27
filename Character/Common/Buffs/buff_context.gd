extends RefCounted
class_name BuffContext

var owner: Object = null
var base_stat_getter: Callable = Callable()
var damage_receiver: Callable = Callable()
var heal_receiver: Callable = Callable()
var alive_getter: Callable = Callable()

func setup(
		new_owner: Object,
		new_base_stat_getter: Callable,
		new_damage_receiver: Callable,
		new_heal_receiver: Callable,
		new_alive_getter: Callable
) -> void:
	owner = new_owner
	base_stat_getter = new_base_stat_getter
	damage_receiver = new_damage_receiver
	heal_receiver = new_heal_receiver
	alive_getter = new_alive_getter

func get_base_stat(stat_id: StringName, fallback: float = 0.0) -> float:
	if base_stat_getter.is_valid():
		return float(base_stat_getter.call(stat_id, fallback))
	return fallback

func apply_damage(amount: float, source: CharacterBody2D = null) -> void:
	if amount <= 0.0 or not damage_receiver.is_valid():
		return
	damage_receiver.call(amount, source)

func heal(amount: float) -> void:
	if amount <= 0.0 or not heal_receiver.is_valid():
		return
	heal_receiver.call(amount)

func is_alive() -> bool:
	if alive_getter.is_valid():
		return bool(alive_getter.call())
	return true

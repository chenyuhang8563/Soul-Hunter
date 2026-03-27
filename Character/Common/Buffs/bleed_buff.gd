extends "res://Character/Common/Buffs/buff_effect.gd"
class_name BleedBuff

var damage_per_tick := 5.0
var source: CharacterBody2D = null

func _init() -> void:
	buff_id = &"bleed"
	stack_key = &"bleed"
	display_name = "Bleed"
	stack_policy = StackPolicy.STACK_VALUES
	max_stacks = 5
	tick_interval = 1.0
	setup_duration(5.0)

func on_tick(context) -> void:
	if context == null or not context.is_alive():
		return
	context.apply_damage(damage_per_tick * float(stack_count), source)

func on_refreshed(incoming) -> void:
	if incoming == null:
		return
	damage_per_tick = float(incoming.damage_per_tick)
	source = incoming.source
	mark_modifiers_dirty()

func on_stacked(incoming) -> void:
	if incoming == null:
		return
	damage_per_tick = float(incoming.damage_per_tick)
	if incoming.source != null:
		source = incoming.source

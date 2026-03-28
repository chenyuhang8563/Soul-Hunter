extends "res://Character/Common/Buffs/buff_effect.gd"
class_name SlowedBuff

const StatModifierScript := preload("res://Character/Common/Buffs/stat_modifier.gd")
const BuffIconScene := preload("res://Scenes/UI/buff_icon.tscn")
const SlowedTexture := preload("res://Assets/Sprites/UI/Buffs/slowed.png")

var move_speed_multiplier_penalty := -0.2

func _init() -> void:
	buff_id = &"slowed"
	stack_key = &"slowed"
	display_name = "Slowed"
	stack_policy = StackPolicy.RESET_DURATION
	max_stacks = 1
	setup_duration(5.0)

func build_modifiers() -> Array:
	return [
		StatModifierScript.new(&"move_speed", move_speed_multiplier_penalty, StatModifierScript.Mode.MULTIPLY, 100),
	]

func on_refreshed(incoming) -> void:
	if incoming == null:
		return
	move_speed_multiplier_penalty = float(incoming.move_speed_multiplier_penalty)
	mark_modifiers_dirty()

func create_icon_instance() -> Node2D:
	var icon = BuffIconScene.instantiate() as Node2D
	if icon != null and icon.has_method("set_icon_texture"):
		icon.set_icon_texture(SlowedTexture)
	return icon

extends "res://Character/Common/Buffs/buff_effect.gd"
class_name SwiftnessBuff

const StatModifierScript := preload("res://Character/Common/Buffs/stat_modifier.gd")
const BuffIconScene := preload("res://Scenes/UI/buff_icon.tscn")
const SwiftnessTexture := preload("res://Assets/Sprites/UI/Buffs/swiftness.png")

var move_speed_multiplier_bonus := 0.25

func _init() -> void:
	buff_id = &"swiftness"
	stack_key = &"swiftness"
	display_name = "Swiftness"
	stack_policy = StackPolicy.RESET_DURATION
	max_stacks = 1
	setup_duration(6.0)

func build_modifiers() -> Array:
	return [
		StatModifierScript.new(&"move_speed", move_speed_multiplier_bonus, StatModifierScript.Mode.MULTIPLY, 100),
	]

func on_refreshed(incoming) -> void:
	if incoming == null:
		return
	move_speed_multiplier_bonus = float(incoming.move_speed_multiplier_bonus)
	mark_modifiers_dirty()

func create_icon_instance() -> Node2D:
	var icon = BuffIconScene.instantiate() as Node2D
	if icon != null and icon.has_method("set_icon_texture"):
		icon.set_icon_texture(SwiftnessTexture)
	return icon

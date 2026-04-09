extends "res://Character/Common/Buffs/buff_effect.gd"
class_name DefenseDownBuff

const StatModifierScript := preload("res://Character/Common/Buffs/stat_modifier.gd")
const BuffIconScene := preload("res://Scenes/UI/buff_icon.tscn")
const DefenseDownTexture := preload("res://Assets/Sprites/UI/Buffs/defense_down.png")

var defense_penalty := 20.0

func _init() -> void:
	buff_id = &"defense_down"
	stack_key = &"defense_down"
	display_name = "Defense Down"
	stack_policy = StackPolicy.RESET_DURATION
	max_stacks = 1
	setup_duration(4.0)

func build_modifiers() -> Array:
	return [
		StatModifierScript.new(&"defense", -defense_penalty, StatModifierScript.Mode.ADD, 100),
	]

func on_refreshed(incoming) -> void:
	if incoming == null:
		return
	defense_penalty = float(incoming.defense_penalty)
	mark_modifiers_dirty()

func create_icon_instance() -> Node2D:
	var icon = BuffIconScene.instantiate() as Node2D
	if icon != null and icon.has_method("set_icon_texture"):
		icon.set_icon_texture(DefenseDownTexture)
	return icon

extends "res://Character/Common/Buffs/buff_effect.gd"
class_name StunnedBuff

const BuffIconScene := preload("res://Scenes/UI/buff_icon.tscn")
const StunnedTexture := preload("res://Assets/Sprites/UI/Buffs/stunned.png")


func _init() -> void:
	buff_id = &"stunned"
	stack_key = &"stunned"
	display_name = "Stunned"
	stack_policy = StackPolicy.RESET_DURATION
	max_stacks = 1
	setup_duration(3.0)


func on_applied(context) -> void:
	if context == null or context.owner == null:
		return
	if context.owner.has_method("set_stunned"):
		context.owner.set_stunned(true)


func on_removed(context) -> void:
	if context == null or context.owner == null:
		return
	if context.owner.has_method("set_stunned"):
		context.owner.set_stunned(false)


func create_icon_instance() -> Node2D:
	var icon = BuffIconScene.instantiate() as Node2D
	if icon != null and icon.has_method("set_icon_texture"):
		icon.set_icon_texture(StunnedTexture)
	return icon

extends Resource
class_name RewardCardDefinition

const RewardEffectDefinitionScript := preload("res://Global/Roguelike/reward_effect_definition.gd")

@export var id: StringName = &""
@export var title := ""
@export_multiline var description := ""
@export var icon: Texture2D
@export_range(0.0, 1000.0, 0.1, "or_greater") var weight := 1.0
@export var effects: Array = []

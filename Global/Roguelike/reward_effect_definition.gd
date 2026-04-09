extends Resource
class_name RewardEffectDefinition

enum EffectType {
	STAT_ADD,
	SKILL,
	LIFESTEAL_PERCENT = SKILL,
	DASH_PATH_DAMAGE = 2,
}

@export var effect_type: EffectType = EffectType.STAT_ADD
@export var stat_id: StringName = &""
@export var effect_id: StringName = &""
@export var value: float = 0.0
@export var duration: float = 0.0
@export var aux_value: float = 0.0

extends Resource
class_name RewardEffectDefinition

enum EffectType {
	STAT_ADD,
	LIFESTEAL_PERCENT,
	DASH_PATH_DAMAGE,
}

@export var effect_type: EffectType = EffectType.STAT_ADD
@export var stat_id: StringName = &""
@export var value: float = 0.0

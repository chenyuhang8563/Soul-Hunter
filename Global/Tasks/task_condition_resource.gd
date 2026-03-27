extends Resource
class_name TaskConditionResource

@export var all_true: PackedStringArray = PackedStringArray()
@export var any_true: PackedStringArray = PackedStringArray()
@export var all_false: PackedStringArray = PackedStringArray()

func matches(facts: Dictionary) -> bool:
	for fact_id_text in all_true:
		if not _is_truthy(facts.get(StringName(fact_id_text), false)):
			return false

	if not any_true.is_empty():
		var has_match := false
		for fact_id_text in any_true:
			if _is_truthy(facts.get(StringName(fact_id_text), false)):
				has_match = true
				break
		if not has_match:
			return false

	for fact_id_text in all_false:
		if _is_truthy(facts.get(StringName(fact_id_text), false)):
			return false

	return true

func _is_truthy(value: Variant) -> bool:
	return bool(value)

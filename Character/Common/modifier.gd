extends RefCounted

enum Mode {
	ADD,
	MULTIPLY,
}

var stat_id: StringName = &""
var value := 0.0
var mode := Mode.ADD
var priority := 0

func _init(
		new_stat_id: StringName = &"",
		new_value: float = 0.0,
		new_mode: int = Mode.ADD,
		new_priority: int = 0
) -> void:
	stat_id = new_stat_id
	value = new_value
	mode = new_mode as Mode
	priority = new_priority

func duplicate_modifier():
	return get_script().new(stat_id, value, mode, priority)

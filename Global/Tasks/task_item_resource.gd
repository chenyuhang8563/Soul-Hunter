extends Resource
class_name TaskItemResource

@export var id: StringName = &""
@export_multiline var title := ""
@export var priority := 0
@export var show_when: Resource

func matches(facts: Dictionary) -> bool:
	if show_when == null:
		return false

	return show_when.matches(facts)

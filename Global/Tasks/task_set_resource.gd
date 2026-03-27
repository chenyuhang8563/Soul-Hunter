extends Resource
class_name TaskSetResource

@export var id: StringName = &""
@export var items: Array[Resource] = []

func get_best_matching_task(facts: Dictionary) -> Resource:
	var best_task: Resource = null

	for item in items:
		if item == null or not item.has_method("matches"):
			continue

		var task_item: Resource = item
		if not task_item.matches(facts):
			continue

		if best_task == null or int(task_item.get("priority")) > int(best_task.get("priority")):
			best_task = task_item

	return best_task

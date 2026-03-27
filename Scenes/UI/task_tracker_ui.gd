extends CanvasLayer

@onready var task_label: Label = $TaskLabel

func _ready() -> void:
	hide()
	bind_to_task_manager()

func bind_to_task_manager() -> void:
	if not TaskManager.task_view_changed.is_connected(_on_task_view_changed):
		TaskManager.task_view_changed.connect(_on_task_view_changed)

	var current_view := TaskManager.get_current_task_view()
	render(
		current_view.get("task_id", &""),
		str(current_view.get("title", "")),
		bool(current_view.get("visible", false))
	)

func render(_task_id: StringName, title: String, task_is_visible: bool) -> void:
	var should_show := task_is_visible and title != ""
	task_label.text = title if should_show else ""
	visible = should_show
	task_label.visible = should_show

func _exit_tree() -> void:
	if TaskManager.task_view_changed.is_connected(_on_task_view_changed):
		TaskManager.task_view_changed.disconnect(_on_task_view_changed)

func _on_task_view_changed(task_id: StringName, title: String, task_is_visible: bool) -> void:
	render(task_id, title, task_is_visible)

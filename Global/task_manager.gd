extends Node

signal session_started(session_id: StringName)
signal task_view_changed(task_id: StringName, title: String, visible: bool)
signal session_finished(session_id: StringName)

var _current_session_id: StringName = &""
var _current_task_set: Resource = null
var _facts: Dictionary = {}
var _current_task_id: StringName = &""
var _current_title := ""
var _current_visible := false

func _ready() -> void:
	if not TaskEventBus.fact_published.is_connected(_on_fact_published):
		TaskEventBus.fact_published.connect(_on_fact_published)

func begin_session(task_set: Resource, session_id: StringName) -> void:
	if task_set == null:
		push_error("TaskManager.begin_session requires a valid task set.")
		return

	if _current_session_id != &"" and _current_session_id != session_id:
		end_session()

	_current_session_id = session_id
	_current_task_set = task_set
	_facts.clear()
	_set_current_view(&"", "", false)
	session_started.emit(_current_session_id)
	_recalculate_current_task()

func end_session(session_id: StringName = &"") -> void:
	if _current_session_id == &"":
		return

	if session_id != &"" and session_id != _current_session_id:
		return

	var finished_session_id := _current_session_id
	_current_session_id = &""
	_current_task_set = null
	_facts.clear()
	_set_current_view(&"", "", false)
	session_finished.emit(finished_session_id)

func get_current_task_view() -> Dictionary:
	return {
		"session_id": _current_session_id,
		"task_id": _current_task_id,
		"title": _current_title,
		"visible": _current_visible,
	}

func _on_fact_published(fact_id: StringName, value: Variant) -> void:
	if _current_session_id == &"" or _current_task_set == null:
		return

	if _facts.has(fact_id) and _facts[fact_id] == value:
		return

	_facts[fact_id] = value
	_recalculate_current_task()

func _recalculate_current_task() -> void:
	if _current_task_set == null:
		_set_current_view(&"", "", false)
		return

	var best_task: Resource = _current_task_set.get_best_matching_task(_facts)
	if best_task == null:
		_set_current_view(&"", "", false)
		return

	_set_current_view(best_task.id, best_task.title, true)

func _set_current_view(task_id: StringName, title: String, visible: bool) -> void:
	if _current_task_id == task_id and _current_title == title and _current_visible == visible:
		return

	_current_task_id = task_id
	_current_title = title
	_current_visible = visible
	task_view_changed.emit(_current_task_id, _current_title, _current_visible)

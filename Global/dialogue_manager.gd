extends Node

signal dialogue_started
signal dialogue_ended

var dialogue_ui_scene = preload("res://Scenes/UI/dialogue_ui.tscn")
var dialogue_ui = null
var current_dialogue_data: Dictionary = {}
var current_node_id: String = ""
var _is_dialogue_active := false

func _ready() -> void:
	dialogue_ui = dialogue_ui_scene.instantiate()
	add_child(dialogue_ui)
	dialogue_ui.dialogue_finished.connect(_on_dialogue_ui_finished)
	dialogue_ui.option_selected.connect(_on_option_selected)

func is_dialogue_active() -> bool:
	return _is_dialogue_active

func start_dialogue(dialogue_data: Dictionary, start_node: String = "start") -> void:
	if _is_dialogue_active:
		end_dialogue()
	if dialogue_data.is_empty() or not dialogue_data.has(start_node):
		push_error("Dialogue data is invalid or missing start node.")
		return
	current_dialogue_data = dialogue_data
	current_node_id = start_node
	_is_dialogue_active = true
	dialogue_started.emit()
	_show_current_node()

func _show_current_node() -> void:
	if current_dialogue_data.has(current_node_id):
		var node_data = current_dialogue_data[current_node_id]
		if dialogue_ui != null:
			dialogue_ui.show_dialogue(node_data)
		else:
			push_error("dialogue_ui is null!")
			end_dialogue()
	else:
		end_dialogue()

func _on_dialogue_ui_finished() -> void:
	var current_node = current_dialogue_data.get(current_node_id, {})
	if current_node.has("next_id") and current_node["next_id"] != "":
		current_node_id = current_node["next_id"]
		_show_current_node()
	else:
		end_dialogue()

func _on_option_selected(next_id: String) -> void:
	if next_id != "":
		current_node_id = next_id
		_show_current_node()
	else:
		end_dialogue()

func end_dialogue() -> void:
	if dialogue_ui != null:
		dialogue_ui.hide_dialogue()
	current_dialogue_data.clear()
	current_node_id = ""
	if not _is_dialogue_active:
		return
	_is_dialogue_active = false
	dialogue_ended.emit()

func extract_avatar_from_sprite(sprite: Sprite2D) -> AtlasTexture:
	if not is_instance_valid(sprite) or not sprite.texture:
		return null
	var tex = sprite.texture
	var hframes = max(1, sprite.hframes)
	var vframes = max(1, sprite.vframes)
	var w = tex.get_width() / float(hframes)
	var h = tex.get_height() / float(vframes)
	var atlas = AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(0, 0, w, h)
	return atlas

extends Node 

signal dialogue_started
signal dialogue_ended

var dialogue_ui_scene = preload("res://Scenes/UI/dialogue_ui.tscn")
var dialogue_ui = null
var current_dialogue_data: Dictionary = {}
var current_node_id: String = ""

func _ready():
	# Instantiate UI and add it to the scene tree
	dialogue_ui = dialogue_ui_scene.instantiate()
	add_child(dialogue_ui)
	
	# Connect signals
	dialogue_ui.dialogue_finished.connect(_on_dialogue_ui_finished)
	dialogue_ui.option_selected.connect(_on_option_selected)

func start_dialogue(dialogue_data: Dictionary, start_node: String = "start"):
	if dialogue_data.is_empty() or not dialogue_data.has(start_node):
		push_error("Dialogue data is invalid or missing start node.")
		return
		
	current_dialogue_data = dialogue_data
	current_node_id = start_node
	
	# Disable player and game input, let dialogue UI handle it
	get_tree().paused = true
	dialogue_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	
	dialogue_started.emit()
	_show_current_node()

func _show_current_node():
	if current_dialogue_data.has(current_node_id):
		var node_data = current_dialogue_data[current_node_id]
		if dialogue_ui:
			dialogue_ui.show_dialogue(node_data)
		else:
			push_error("dialogue_ui is null!")
			end_dialogue()
	else:
		end_dialogue()

func _on_dialogue_ui_finished():
	# Called when user presses Space/Click and there are no options
	var current_node = current_dialogue_data.get(current_node_id, {})
	if current_node.has("next_id") and current_node["next_id"] != "":
		current_node_id = current_node["next_id"]
		_show_current_node()
	else:
		end_dialogue()

func _on_option_selected(next_id: String):
	if next_id != "":
		current_node_id = next_id
		_show_current_node()
	else:
		end_dialogue()

func end_dialogue():
	# 断开信号连接，防止内存泄漏
	if dialogue_ui:
		if dialogue_ui.dialogue_finished.is_connected(_on_dialogue_ui_finished):
			dialogue_ui.dialogue_finished.disconnect(_on_dialogue_ui_finished)
		if dialogue_ui.option_selected.is_connected(_on_option_selected):
			dialogue_ui.option_selected.disconnect(_on_option_selected)
		dialogue_ui.hide_dialogue()
	
	current_dialogue_data.clear()
	current_node_id = ""
	
	# Delay unpausing slightly to consume the remaining input event
	# and prevent it from triggering actions like jumping immediately.
	await get_tree().create_timer(0.1).timeout
	get_tree().paused = false
	
	dialogue_ended.emit()
	
	# 重新连接信号，为下次对话做准备
	_reconnect_dialogue_signals()

func _reconnect_dialogue_signals() -> void:
	# 确保信号在下次对话时可用
	if dialogue_ui:
		if not dialogue_ui.dialogue_finished.is_connected(_on_dialogue_ui_finished):
			dialogue_ui.dialogue_finished.connect(_on_dialogue_ui_finished)
		if not dialogue_ui.option_selected.is_connected(_on_option_selected):
			dialogue_ui.option_selected.connect(_on_option_selected)

func extract_avatar_from_sprite(sprite: Sprite2D) -> AtlasTexture:
	if not is_instance_valid(sprite) or not sprite.texture:
		return null
		
	var tex = sprite.texture
	var hframes = sprite.hframes
	var vframes = sprite.vframes
	
	var w = tex.get_width() / float(hframes)
	var h = tex.get_height() / float(vframes)
	
	var atlas = AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(0, 0, w, h)
	return atlas

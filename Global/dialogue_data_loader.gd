class_name DialogueDataLoader

## 从 JSON 文件加载对话数据并生成运行时格式
func load_dialogue(json_path: String, avatar: AtlasTexture) -> Dictionary:
	var file = FileAccess.open(json_path, FileAccess.READ)
	if not file:
		push_error("Cannot open dialogue file: " + json_path)
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("JSON parse error: " + json.get_error_message())
		return {}
	
	var data = json.get_data()
	return _build_runtime_dialogue(data, avatar)

func _build_runtime_dialogue(json_data: Dictionary, avatar: AtlasTexture) -> Dictionary:
	var result = {}
	var nodes = json_data.get("nodes", {})
	var default_name = json_data.get("default_name", "Unknown")
	
	for node_id in nodes:
		var node = nodes[node_id]
		var runtime_node = {
			"name": default_name,
			"avatar": avatar,
			"text": node.get("text", ""),
		}
		
		if node.has("options"):
			var options = []
			for opt in node["options"]:
				options.append({
					"text": opt["text"],
					"next_id": opt["next_id"]
				})
			runtime_node["options"] = options
		elif node.has("next_id"):
			runtime_node["next_id"] = node["next_id"]
		
		result[node_id] = runtime_node
	
	return result

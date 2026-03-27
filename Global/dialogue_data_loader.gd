class_name DialogueDataLoader

var _parsed_cache: Dictionary = {}
var _runtime_cache: Dictionary = {}

## 从 JSON 文件加载对话数据并生成运行时格式
func load_dialogue(json_path: String, avatar: AtlasTexture) -> Dictionary:
	if json_path.is_empty():
		push_error("Dialogue path is empty.")
		return {}
	var runtime_cache_key := "%s|%s" % [json_path, _get_avatar_cache_key(avatar)]
	if _runtime_cache.has(runtime_cache_key):
		return _runtime_cache[runtime_cache_key].duplicate(true)
	var parsed_data := _load_parsed_dialogue(json_path)
	if parsed_data.is_empty():
		return {}
	var runtime_dialogue := _build_runtime_dialogue(parsed_data, avatar)
	if runtime_dialogue.is_empty():
		return {}
	_runtime_cache[runtime_cache_key] = runtime_dialogue.duplicate(true)
	return runtime_dialogue

func _load_parsed_dialogue(json_path: String) -> Dictionary:
	if _parsed_cache.has(json_path):
		return _parsed_cache[json_path].duplicate(true)
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
	if not _is_valid_dialogue_data(data):
		return {}
	_parsed_cache[json_path] = data.duplicate(true)
	return data

func _build_runtime_dialogue(json_data: Dictionary, avatar: AtlasTexture) -> Dictionary:
	var result := {}
	var nodes: Dictionary = json_data.get("nodes", {})
	var default_name = str(json_data.get("default_name", "Unknown"))
	for node_id in nodes.keys():
		var node = nodes[node_id]
		if not (node is Dictionary):
			continue
		var runtime_node := {
			"name": default_name,
			"avatar": avatar,
			"text": str(node.get("text", "")),
		}
		if node.has("options"):
			var options := []
			for opt in node["options"]:
				if not (opt is Dictionary) or not opt.has("text") or not opt.has("next_id"):
					continue
				options.append({
					"text": str(opt["text"]),
					"next_id": str(opt["next_id"]),
				})
			runtime_node["options"] = options
		elif node.has("next_id"):
			runtime_node["next_id"] = str(node["next_id"])
		result[str(node_id)] = runtime_node
	return result

func _is_valid_dialogue_data(data: Variant) -> bool:
	if not (data is Dictionary):
		push_error("Dialogue data must be a dictionary.")
		return false
	if not data.has("nodes") or not (data["nodes"] is Dictionary):
		push_error("Dialogue data is missing a valid nodes dictionary.")
		return false
	if not data["nodes"].has("start"):
		push_error("Dialogue data is missing the start node.")
		return false
	return true

func _get_avatar_cache_key(avatar: AtlasTexture) -> String:
	if avatar == null:
		return "no_avatar"
	return str(avatar.get_rid())

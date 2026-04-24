# Global/PropSystem/prop_csv_loader.gd
## CSV 物品配置加载器
class_name PropCsvLoader

const PropItemScript := preload("res://Global/PropSystem/prop_item.gd")

## 从 CSV 文件加载物品配置
## 返回 { id(int): PropItem }
static func load_from_csv(path: String) -> Dictionary:
	var result: Dictionary = {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("无法打开CSV文件: ", path, " error: ", FileAccess.get_open_error())
		return result

	# 读取表头行
	var header_line: String = file.get_line()
	var headers: PackedStringArray = header_line.split(",")
	if headers.is_empty():
		push_error("CSV文件缺少表头: ", path)
		return result

	# 逐行解析数据
	while not file.eof_reached():
		var line: String = file.get_line()
		line = line.strip_edges()
		if line.is_empty():
			continue

		var values: PackedStringArray = _parse_csv_line(line)
		if values.size() < 2:
			continue

		var item := PropItemScript.new()
		for i in mini(headers.size(), values.size()):
			var key: String = headers[i].strip_edges()
			var val: String = values[i].strip_edges()
			_set_prop_field(item, key, val)

		if item.id > 0:
			result[item.id] = item

	file.close()
	return result

## 解析单行 CSV（处理引号内的逗号）
static func _parse_csv_line(line: String) -> PackedStringArray:
	var result: PackedStringArray = []
	var current: String = ""
	var in_quotes: bool = false
	for c in line:
		if c == '"':
			in_quotes = not in_quotes
		elif c == ',' and not in_quotes:
			result.append(current)
			current = ""
		else:
			current += c
	result.append(current)
	return result

## 将 CSV 字段值写入 PropItem 属性
static func _set_prop_field(item, key: String, value: String) -> void:
	match key:
		"id":
			item.id = value.to_int()
		"name":
			item.name = value
		"type":
			item.type = PropItemScript.PropType.get(value) if PropItemScript.PropType.has(value) else PropItemScript.PropType.MATERIAL
		"rarity":
			item.rarity = PropItemScript.PropRarity.get(value) if PropItemScript.PropRarity.has(value) else PropItemScript.PropRarity.COMMON
		"description":
			item.description = value
		"icon_path":
			item.icon_path = value
		"max_stack":
			item.max_stack = value.to_int()
		"buy_price":
			item.buy_price = value.to_int()
		"sell_price":
			item.sell_price = value.to_int()

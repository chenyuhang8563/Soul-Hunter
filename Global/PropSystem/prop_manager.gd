# Global/PropSystem/prop_manager.gd
## 全局物品/道具管理器（Autoload 单例）
##
## 职责：
##   - 从 CSV 配置表加载所有物品的静态数据
##   - 管理背包运行时数据（堆叠/拆分/消耗）
##   - 通过 signal 广播所有变更，供 UI 层响应更新
##
## 使用方式：
##   PropManager.add_prop(1, 5)        # 添加 5 瓶生命药水
##   PropManager.remove_prop(1, 2)      # 消耗 2 瓶
##   PropManager.use_prop(1)            # 使用 1 瓶（发射 signal）
##   PropManager.get_prop_count(1)      # 查询总数
##   PropManager.get_all_slots()        # 获取所有槽位
extends Node

# ============================================================
#  预加载依赖脚本
# ============================================================

const _PropItemScript := preload("res://Global/PropSystem/prop_item.gd")
const _PropSlotScript := preload("res://Global/PropSystem/prop_slot.gd")
const _PropCsvLoaderScript := preload("res://Global/PropSystem/prop_csv_loader.gd")

# ============================================================
#  Signals — UI 层连接这些信号实现数据与表现分离
# ============================================================

## 物品增加时触发 (item_id, added_count, total_count)
signal prop_added(item_id: int, count: int, total: int)
## 物品移除时触发 (item_id, removed_count, total_count)
signal prop_removed(item_id: int, count: int, total: int)
## 物品被使用时触发 (item_id)
signal prop_used(item_id: int)
## 物品数量变化时触发 (item_id, total_count)
signal prop_count_changed(item_id: int, total: int)

# ============================================================
#  配置
# ============================================================

## CSV 配置文件路径（可在 _ready() 前修改以覆盖默认路径）
var config_file_path: String = "res://Data/Props/prop_config.csv"

# ============================================================
#  内部状态
# ============================================================

## 物品静态配置字典 { id: PropItem }
var _config_dict: Dictionary = {}

## 背包槽位列表（运行时数据）
var _slots = []

# ============================================================
#  初始化
# ============================================================

func _ready() -> void:
	initialize()

## 初始化管理器，加载配置表
func initialize() -> void:
	_reload_config()

## 重新加载配置表（支持热重载）
func _reload_config() -> void:
	_config_dict = _PropCsvLoaderScript.load_from_csv(config_file_path)
	if _config_dict.is_empty():
		push_warning("PropManager: 未加载到任何物品配置，请检查 CSV 路径: ", config_file_path)
	else:
		print("PropManager: 成功加载 ", _config_dict.size(), " 种物品配置")

# ============================================================
#  公开 API
# ============================================================

## 获取指定物品的静态配置（只读）
func get_prop_config(item_id: int):
	return _config_dict.get(item_id)

## 向背包添加指定数量的物品
##
## 自动处理超出堆叠上限时的分格逻辑：
##   1. 优先填满已有未满堆叠
##   2. 超出部分创建新的槽位
func add_prop(item_id: int, count: int) -> void:
	if count <= 0:
		return

	var config = _config_dict.get(item_id)
	if config == null:
		push_error("PropManager.add_prop: 找不到物品配置 ID=", item_id)
		return

	var remaining: int = count
	var max_stack: int = config.max_stack

	# 不可堆叠物品每格只放 1 个
	if max_stack <= 0:
		max_stack = 1

	# 1. 填充已有未满堆叠
	for slot in _slots:
		if slot.item_id != item_id:
			continue
		if slot.count >= max_stack:
			continue

		var space: int = max_stack - slot.count
		var to_add: int = mini(remaining, space)
		slot.count += to_add
		remaining -= to_add

		if remaining <= 0:
			break

	# 2. 剩余部分创建新槽位
	while remaining > 0:
		var to_add: int = mini(remaining, max_stack)
		var new_slot = _PropSlotScript.new()
		new_slot.item_id = item_id
		new_slot.count = to_add
		_slots.append(new_slot)
		remaining -= to_add

	var total: int = get_prop_count(item_id)
	prop_added.emit(item_id, count, total)
	prop_count_changed.emit(item_id, total)

## 从背包移除指定数量的物品
##
## 优先消耗数量较少的堆叠，以使背包更紧凑。
## 返回 true 表示移除成功，false 表示数量不足。
func remove_prop(item_id: int, count: int) -> bool:
	if count <= 0:
		return true

	var total: int = get_prop_count(item_id)
	if total < count:
		push_warning("PropManager.remove_prop: 物品不足 ID=", item_id,
				" 需要=", count, " 拥有=", total)
		return false

	var remaining: int = count

	# 收集所有同 ID 的槽位索引
	var indices: Array[int] = []
	for i in _slots.size():
		if _slots[i].item_id == item_id:
			indices.append(i)

	# 按数量升序排列 —— 优先消耗数量少的堆叠
	indices.sort_custom(func(a: int, b: int) -> bool:
		return _slots[a].count < _slots[b].count
	)

	# 逐格消耗
	for idx in indices:
		if remaining <= 0:
			break
		var slot = _slots[idx]
		if slot.count <= remaining:
			remaining -= slot.count
			_slots[idx] = null  # 标记移除
		else:
			slot.count -= remaining
			remaining = 0

	# 移除空槽位
	_slots = _slots.filter(func(s): return s != null)

	var new_total: int = get_prop_count(item_id)
	prop_removed.emit(item_id, count, new_total)
	prop_count_changed.emit(item_id, new_total)
	return true

## 使用物品 —— 消耗 1 个并发射 signal，由外部订阅者决定具体效果
func use_prop(item_id: int) -> void:
	if get_prop_count(item_id) <= 0:
		push_warning("PropManager.use_prop: 物品不足 ID=", item_id)
		return

	remove_prop(item_id, 1)
	prop_used.emit(item_id)

## 查询某种物品在背包中的总数量
func get_prop_count(item_id: int) -> int:
	var total: int = 0
	for slot in _slots:
		if slot.item_id == item_id:
			total += slot.count
	return total

## 获取背包中所有槽位的副本（用于 UI 渲染）
func get_all_slots():
	return _slots.duplicate()

## 获取所有已加载的物品配置副本
func get_all_configs() -> Dictionary:
	return _config_dict.duplicate()

## 清空整个背包
func clear() -> void:
	_slots.clear()

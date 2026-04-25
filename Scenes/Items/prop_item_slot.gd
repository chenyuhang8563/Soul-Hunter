# Scenes/Items/prop_item_slot.gd
## 物品槽位 UI 控件 —— 显示物品图标 + 右下角堆叠数量
class_name PropItemSlot
extends Control

signal used(item_id: int)

@onready var _slot_bg: TextureRect = $SlotBg
@onready var _item_icon: TextureRect = $ItemIcon
@onready var _stack_label: Label = $StackLabel

var _item_id: int = 0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed \
			and event.double_click:
		if _item_id > 0:
			used.emit(_item_id)


## 用 PropSlot 数据填充槽位
func setup_from_slot(slot) -> void:
	if slot == null:
		clear()
		return
	setup(slot.item_id, slot.count)


## 用物品 ID 和数量填充槽位
func setup(item_id: int, count: int) -> void:
	_item_id = item_id
	var config = PropManager.get_prop_config(item_id)
	if config == null:
		clear()
		return

	# 加载图标（精灵表仅取第 0 帧，8x8）
	if config.icon_path != "":
		var tex = load(config.icon_path) as Texture2D
		if tex != null:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2i(0, 0, 8, 8)
			_item_icon.texture = atlas
			_item_icon.show()
		else:
			_item_icon.hide()
	else:
		_item_icon.hide()

	# 堆叠数量（数量 > 1 或 不可堆叠但数量 > 0 时显示）
	if count > 1:
		_stack_label.text = str(count)
		_stack_label.show()
	else:
		_stack_label.hide()

	_slot_bg.show()


## 清空槽位
func clear() -> void:
	_item_id = 0
	_item_icon.texture = null
	_item_icon.hide()
	_stack_label.hide()

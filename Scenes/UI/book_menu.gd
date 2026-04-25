# Scenes/UI/book_menu.gd
## 翻页式书籍菜单 —— 背包界面（未来扩展装备/天赋页）
extends Control

# ============================================================
#  Node 引用
# ============================================================

@onready var _book_sprite: AnimatedSprite2D = $BookSprite
@onready var _red_tab: TextureButton = $RedTab
@onready var _page_corner: Node2D = $PageCorner
@onready var _backpack_icon: Sprite2D = $BackPackIcon
@onready var _title_label: Label = $Label
@onready var _container1: GridContainer = $ItemContainer1
@onready var _container2: GridContainer = $ItemContainer2
@onready var _divider: Sprite2D = $Divider

# ============================================================
#  状态
# ============================================================

var _is_open := false
var _is_animating := false
static var _items_initialized := false

# ============================================================
#  初始化
# ============================================================

func _ready() -> void:
	# 停止自动播放，初始为合书状态
	_book_sprite.stop()
	_book_sprite.frame = 0

	# 所有 UI 元素初始隐藏（仅书脊可见）
	_set_pages_visible(false)

	# 监听动画完成
	_book_sprite.animation_finished.connect(_on_animation_finished)

	# 添加初始物品
	_add_placeholder_items()

	# 连接所有物品槽位的双击使用信号
	_connect_slot_signals()

	# 自身默认隐藏
	visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_TAB and event.pressed:
		toggle()
		get_viewport().set_input_as_handled()

# ============================================================
#  开关
# ============================================================

func toggle() -> void:
	if _is_open:
		close()
	elif not _is_animating:
		open()

func open() -> void:
	if _is_open:
		return
	_is_animating = true
	_is_open = true

	# 重置翻书动画（确保从第 0 帧开始播放）
	_book_sprite.stop()
	_book_sprite.frame = 0
	_set_pages_visible(false)
	_book_sprite.play("default")

	# 显示自身
	visible = true

	# 暂停游戏
	get_tree().paused = true


func close() -> void:
	_is_open = false
	_is_animating = false
	_book_sprite.stop()
	_book_sprite.frame = 0
	_set_pages_visible(false)
	visible = false

	# 恢复游戏
	get_tree().paused = false

# ============================================================
#  翻书动画回调
# ============================================================

func _on_animation_finished() -> void:
	_is_animating = false
	# 翻到最后一帧（书完全打开）
	_book_sprite.stop()
	_book_sprite.frame = _book_sprite.sprite_frames.get_frame_count("default") - 1
	# 显示页面内容
	_set_pages_visible(true)
	_populate_backpack()

# ============================================================
#  页面内容控制
# ============================================================

func _set_pages_visible(v: bool) -> void:
	_red_tab.visible = v
	_page_corner.visible = v
	_backpack_icon.visible = v
	_title_label.visible = v
	_container1.visible = v
	_container2.visible = v
	_divider.visible = v

func _populate_backpack() -> void:
	var slots = PropManager.get_all_slots()
	var all_slot_nodes = _container1.get_children() + _container2.get_children()

	for i in all_slot_nodes.size():
		if i < slots.size():
			all_slot_nodes[i].setup_from_slot(slots[i])
		else:
			all_slot_nodes[i].clear()

func _connect_slot_signals() -> void:
	var all_slots = _container1.get_children() + _container2.get_children()
	for slot in all_slots:
		if slot.has_signal("used") and not slot.used.is_connected(_on_slot_used):
			slot.used.connect(_on_slot_used)

func _on_slot_used(item_id: int) -> void:
	PropManager.use_prop(item_id)
	_populate_backpack()

# ============================================================
#  初始占位数据
# ============================================================

func _add_placeholder_items() -> void:
	if _items_initialized:
		return
	_items_initialized = true

	# 2 瓶生命药水（ID 1），3 瓶魔法药水（ID 2）
	PropManager.add_prop(1, 2)
	PropManager.add_prop(2, 3)

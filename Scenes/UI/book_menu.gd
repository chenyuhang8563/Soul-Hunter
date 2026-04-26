# Scenes/UI/book_menu.gd
## 翻页式书籍菜单 —— 背包界面（未来扩展装备/天赋页）
extends Control

# ============================================================
#  Node 引用
# ============================================================

@onready var _book_sprite: AnimatedSprite2D = $BookSprite
@onready var _open_content: Control = $OpenContent
@onready var _backpack_tab: TextureButton = $OpenContent/Tabs/BackpackTab
@onready var _settings_tab: TextureButton = $OpenContent/Tabs/SettingsTab
@onready var _backpack_page: Control = $OpenContent/Pages/BackpackPage
@onready var _settings_page: Control = $OpenContent/Pages/SettingsPage
@onready var _container1: GridContainer = $OpenContent/Pages/BackpackPage/ItemContainer1
@onready var _container2: GridContainer = $OpenContent/Pages/BackpackPage/ItemContainer2

# ============================================================
#  状态
# ============================================================

var _is_open := false
var _is_animating := false
static var _items_initialized := false

const PAGE_BACKPACK := "backpack"
const PAGE_SETTINGS := "settings"
const ANIM_OPEN := "default"
const ANIM_NEXT_PAGE := "next_page"
const ANIM_PREVIOUS_PAGE := "previous_page"

var _current_page := PAGE_BACKPACK
var _pending_page := PAGE_BACKPACK
var _is_page_turning := false

# ============================================================
#  初始化
# ============================================================

func _ready() -> void:
	# 停止自动播放，初始为合书状态
	_book_sprite.stop()
	_book_sprite.animation = ANIM_OPEN
	_book_sprite.frame = 0

	# 所有 UI 元素初始隐藏（仅书脊可见）
	_set_open_content_visible(false)

	# 监听动画完成
	if not _book_sprite.animation_finished.is_connected(_on_animation_finished):
		_book_sprite.animation_finished.connect(_on_animation_finished)
	if not _backpack_tab.pressed.is_connected(_on_backpack_tab_pressed):
		_backpack_tab.pressed.connect(_on_backpack_tab_pressed)
	if not _settings_tab.pressed.is_connected(_on_settings_tab_pressed):
		_settings_tab.pressed.connect(_on_settings_tab_pressed)

	# 添加初始物品
	_add_placeholder_items()

	# 连接所有物品槽位的双击使用信号
	_connect_slot_signals()
	_select_page(PAGE_BACKPACK)

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
	_current_page = PAGE_BACKPACK

	# 重置翻书动画（确保从第 0 帧开始播放）
	_book_sprite.stop()
	_book_sprite.animation = ANIM_OPEN
	_book_sprite.frame = 0
	_set_open_content_visible(false)
	_book_sprite.play(ANIM_OPEN)

	# 显示自身
	visible = true

	# 暂停游戏
	get_tree().paused = true


func close() -> void:
	_is_open = false
	_is_animating = false
	_is_page_turning = false
	_book_sprite.stop()
	_book_sprite.animation = ANIM_OPEN
	_book_sprite.frame = 0
	_set_open_content_visible(false)
	visible = false

	# 恢复游戏
	get_tree().paused = false

# ============================================================
#  翻书动画回调
# ============================================================

func _on_animation_finished() -> void:
	_is_animating = false
	_book_sprite.stop()

	if _is_page_turning:
		_is_page_turning = false
		_book_sprite.frame = _book_sprite.sprite_frames.get_frame_count(_book_sprite.animation) - 1
		_select_page(_pending_page)
		return

	# 翻到最后一帧（书完全打开）
	_book_sprite.frame = _book_sprite.sprite_frames.get_frame_count(ANIM_OPEN) - 1
	_set_open_content_visible(true)
	_select_page(_current_page)

# ============================================================
#  页面内容控制
# ============================================================

func _set_open_content_visible(v: bool) -> void:
	_open_content.visible = v


func _select_page(page_id: String) -> void:
	if page_id != PAGE_BACKPACK and page_id != PAGE_SETTINGS:
		page_id = PAGE_BACKPACK

	_current_page = page_id
	_backpack_page.visible = page_id == PAGE_BACKPACK
	_settings_page.visible = page_id == PAGE_SETTINGS

	if page_id == PAGE_BACKPACK:
		_populate_backpack()


func _turn_to_page(page_id: String) -> void:
	if page_id != PAGE_BACKPACK and page_id != PAGE_SETTINGS:
		page_id = PAGE_BACKPACK
	if page_id == _current_page or _is_animating:
		return

	_pending_page = page_id
	_is_animating = true
	_is_page_turning = true

	var turn_animation := ANIM_NEXT_PAGE
	if _get_page_index(page_id) < _get_page_index(_current_page):
		turn_animation = ANIM_PREVIOUS_PAGE

	_book_sprite.stop()
	_book_sprite.animation = turn_animation
	_book_sprite.frame = 0
	_book_sprite.play(turn_animation)


func _get_page_index(page_id: String) -> int:
	match page_id:
		PAGE_BACKPACK:
			return 0
		PAGE_SETTINGS:
			return 1
		_:
			return 0


func _on_backpack_tab_pressed() -> void:
	_turn_to_page(PAGE_BACKPACK)


func _on_settings_tab_pressed() -> void:
	_turn_to_page(PAGE_SETTINGS)

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

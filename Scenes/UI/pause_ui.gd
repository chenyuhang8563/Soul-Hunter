extends CanvasLayer
class_name PauseUI

signal resume_requested
signal exit_requested

enum Page {
	MAIN_MENU,
	REWARDS_DETAILS,
}

const SharedLabelSettings := preload("res://Resources/new_label_settings.tres")
const REWARD_ROWS_PER_COLUMN := 4

@onready var root: Control = $Root
@onready var main_panel: PanelContainer = $Root/MainPanel
@onready var rewards_panel: PanelContainer = $Root/RewardsPanel
@onready var resume_button: Button = $Root/MainPanel/MainMenu/ResumeButton
@onready var run_rewards_button: Button = $Root/MainPanel/MainMenu/RunRewardsButton
@onready var settings_button: Button = $Root/MainPanel/MainMenu/SettingsButton
@onready var exit_button: Button = $Root/MainPanel/MainMenu/ExitButton
@onready var back_button: Button = $Root/RewardsPanel/Content/RewardsHeader/BackButton
@onready var rewards_grid: GridContainer = $Root/RewardsPanel/Content/RewardsGrid
@onready var base_stats_label: Label = $Root/RewardsPanel/Content/BaseStatsLabel

var _current_page: Page = Page.MAIN_MENU
var _player: Node = null
var _reward_lookup := {}
var _reward_entry_texts: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	settings_button.disabled = true
	resume_button.pressed.connect(_on_resume_pressed)
	run_rewards_button.pressed.connect(open_rewards_page)
	exit_button.pressed.connect(func() -> void:
		exit_requested.emit()
	)
	back_button.pressed.connect(func() -> void:
		_show_page(Page.MAIN_MENU)
	)
	hide_pause()

func show_pause(player: Node, reward_cards: Array) -> void:
	_player = player
	_rebuild_reward_lookup(reward_cards)
	_refresh_rewards_data()
	visible = true
	_show_page(Page.MAIN_MENU)

func hide_pause() -> void:
	visible = false
	_show_page(Page.MAIN_MENU)

func open_rewards_page() -> void:
	_refresh_rewards_data()
	_show_page(Page.REWARDS_DETAILS)

func handle_pause_action() -> bool:
	if not visible:
		return false
	if _current_page == Page.REWARDS_DETAILS:
		_show_page(Page.MAIN_MENU)
		return true
	_on_resume_pressed()
	return true

func get_current_page() -> Page:
	return _current_page

func get_reward_entry_texts() -> Array[String]:
	return _reward_entry_texts.duplicate()

func get_base_stats_text() -> String:
	return base_stats_label.text

func _on_resume_pressed() -> void:
	hide_pause()
	resume_requested.emit()

func _show_page(page: Page) -> void:
	_current_page = page
	main_panel.visible = page == Page.MAIN_MENU
	rewards_panel.visible = page == Page.REWARDS_DETAILS

func _rebuild_reward_lookup(reward_cards: Array) -> void:
	_reward_lookup.clear()
	for card in reward_cards:
		if card == null:
			continue
		_reward_lookup[card.id] = card

func _refresh_rewards_data() -> void:
	_reward_entry_texts = _build_reward_entry_texts()
	for child in rewards_grid.get_children():
		child.queue_free()
	for text in _build_column_first_entries(_reward_entry_texts):
		var label := Label.new()
		label.label_settings = SharedLabelSettings
		label.text = text
		rewards_grid.add_child(label)
	base_stats_label.text = _build_base_stats_text()

func _build_reward_entry_texts() -> Array[String]:
	var texts: Array[String] = []
	var controller = _resolve_run_modifier_controller()
	if controller != null:
		for card_id in controller.get_selected_cards():
			var card = _reward_lookup.get(card_id)
			texts.append(card.title if card != null else str(card_id))
	if texts.is_empty():
		texts.append("No rewards selected yet")
	return texts

func _build_column_first_entries(source: Array[String]) -> Array[String]:
	var arranged: Array[String] = []
	var column_count := maxi(1, int(ceil(float(source.size()) / float(REWARD_ROWS_PER_COLUMN))))
	for row in range(REWARD_ROWS_PER_COLUMN):
		for column in range(column_count):
			var index := column * REWARD_ROWS_PER_COLUMN + row
			if index < source.size():
				arranged.append(source[index])
	return arranged

func _build_base_stats_text() -> String:
	if _player == null or not _player.has_method("get_base_stat_value"):
		return "HP --  ATK --  DEF --  CRIT --  LS --  INT --"
	var controller = _resolve_run_modifier_controller()
	var hp := _read_stat(&"max_health", 0.0, controller)
	var atk := _read_stat(&"light_attack_damage", 0.0, controller)
	var defense := _read_stat(&"defense", 0.0, controller)
	var crit := _read_stat(&"crit_chance", 0.0, controller)
	var interval := _read_stat(&"attack_cooldown", 0.30, controller)
	var lifesteal: float = controller.get_lifesteal_percent() if controller != null else 0.0
	return "HP %d  ATK %d  DEF %d  CRIT %d%%  LS %d%%  INT %.2fs" % [hp, atk, defense, crit, lifesteal, interval]

func _read_stat(stat_id: StringName, fallback: float, controller) -> float:
	var base_value := float(_player.get_base_stat_value(stat_id, fallback))
	if controller == null:
		return base_value
	return float(controller.modify_stat_value(stat_id, base_value))

func _resolve_run_modifier_controller():
	if _player == null or not _player.has_method("ensure_run_modifier_controller"):
		return null
	return _player.ensure_run_modifier_controller()

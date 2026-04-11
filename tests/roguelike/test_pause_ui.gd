extends GutTest

const PAUSE_UI_SCENE := preload("res://Scenes/UI/pause_ui.tscn")
const REWARD_EFFECT_SCRIPT := preload("res://Global/Roguelike/reward_effect_definition.gd")
const REWARD_CARD_SCRIPT := preload("res://Global/Roguelike/reward_card_definition.gd")
const RUN_MODIFIER_CONTROLLER_SCRIPT := preload("res://Character/Common/run_modifier_controller.gd")


class FakePlayer:
	extends Node

	signal damage_dealt(target, final_damage)
	signal dash_finished(start_position, end_position)

	var _base_stats := {
		&"max_health": 450.0,
		&"light_attack_damage": 25.0,
		&"defense": 0.0,
		&"crit_chance": 5.0,
		&"attack_cooldown": 0.30,
	}
	var _run_modifier_controller = null
	var _buffed_defense_offset := 0.0

	func get_base_stat_value(stat_id: StringName, fallback: float = 0.0) -> float:
		return float(_base_stats.get(stat_id, fallback))

	func ensure_run_modifier_controller():
		if _run_modifier_controller == null:
			_run_modifier_controller = RUN_MODIFIER_CONTROLLER_SCRIPT.new()
			_run_modifier_controller.setup(self)
		return _run_modifier_controller

	func set_buffed_defense_offset(value: float) -> void:
		_buffed_defense_offset = value

	func get_stat_value(stat_id: StringName, fallback: float = 0.0) -> float:
		var value := get_base_stat_value(stat_id, fallback)
		if stat_id == &"defense":
			value += _buffed_defense_offset
		return value


func test_pause_ui_opens_on_main_menu_with_settings_disabled() -> void:
	var pause_ui = autofree(PAUSE_UI_SCENE.instantiate())
	add_child(pause_ui)

	pause_ui.show_pause(null, [])

	assert_true(pause_ui.visible, "Pause UI should become visible when opened")
	assert_eq(pause_ui.get_current_page(), pause_ui.Page.MAIN_MENU, "Pause UI should open on the main menu page")
	assert_true(pause_ui.get_node("Root/MainPanel/MainMenu/SettingsButton").disabled, "Settings button should stay disabled")


func test_run_rewards_page_lists_titles_and_formats_base_stats_without_buffs() -> void:
	var pause_ui = autofree(PAUSE_UI_SCENE.instantiate())
	add_child(pause_ui)

	var player: FakePlayer = autofree(FakePlayer.new())
	var controller = player.ensure_run_modifier_controller()
	var effect = REWARD_EFFECT_SCRIPT.new()
	effect.effect_type = REWARD_EFFECT_SCRIPT.EffectType.STAT_ADD
	effect.stat_id = &"defense"
	effect.value = 10.0

	var card = REWARD_CARD_SCRIPT.new()
	card.id = &"defense_up"
	card.title = "Defense +10"
	card.effects = [effect]
	controller.apply_reward_card(card)
	player.set_buffed_defense_offset(-20.0)

	pause_ui.show_pause(player, [card])
	pause_ui.open_rewards_page()

	assert_eq(pause_ui.get_current_page(), pause_ui.Page.REWARDS_DETAILS, "Run Rewards should switch to the details page")
	assert_eq(pause_ui.get_reward_entry_texts(), ["Defense +10"], "Reward details should show reward titles")
	assert_string_contains(pause_ui.get_base_stats_text(), "DEF 10", "Base stats should include run rewards")
	assert_false(pause_ui.get_base_stats_text().contains("DEF -10"), "Base stats should ignore temporary buff changes")


func test_pause_action_from_rewards_page_returns_to_main_menu() -> void:
	var pause_ui = autofree(PAUSE_UI_SCENE.instantiate())
	add_child(pause_ui)

	pause_ui.show_pause(null, [])
	pause_ui.open_rewards_page()

	assert_true(pause_ui.handle_pause_action(), "Pause action should be consumed by the pause UI")
	assert_eq(pause_ui.get_current_page(), pause_ui.Page.MAIN_MENU, "Pause action on rewards page should return to main menu")

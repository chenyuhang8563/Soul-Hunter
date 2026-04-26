extends GutTest

const BookMenuScene := preload("res://Scenes/UI/book_menu.tscn")

class FakeAudioManager:
	extends Node

	var blur_call_count := 0

	func _ready() -> void:
		add_to_group(&"audio_manager_service")

	func set_bgm_pause_blur(_enabled: bool) -> void:
		blur_call_count += 1

var _menu: Control


func before_each() -> void:
	_menu = BookMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu._ready()


func test_default_page_is_backpack() -> void:
	_menu._select_page("backpack")

	assert_true(_menu.get_node("OpenContent/Pages/BackpackPage").visible)
	assert_false(_menu.get_node("OpenContent/Pages/SettingsPage").visible)
	assert_eq(_menu.get_node("OpenContent/Pages/BackpackPage/TitleLabel").text, "BackPack")


func test_settings_tab_switches_to_settings_page() -> void:
	_menu.get_node("OpenContent/Tabs/SettingsTab").pressed.emit()

	assert_eq(_menu.get_node("BookSprite").animation, &"next_page")
	assert_false(_menu.get_node("OpenContent/Pages/BackpackPage").visible)
	assert_false(_menu.get_node("OpenContent/Pages/SettingsPage").visible)
	assert_false(_menu.get_node("OpenContent/PageChrome/PageCorner").visible)

	_menu._on_animation_finished()

	assert_false(_menu.get_node("OpenContent/Pages/BackpackPage").visible)
	assert_true(_menu.get_node("OpenContent/Pages/SettingsPage").visible)
	assert_true(_menu.get_node("OpenContent/PageChrome/PageCorner").visible)
	assert_eq(_menu.get_node("OpenContent/Pages/SettingsPage/TitleLabel").text, "Settings")


func test_backpack_tab_switches_back_to_backpack_page() -> void:
	_menu.get_node("OpenContent/Tabs/SettingsTab").pressed.emit()
	_menu._on_animation_finished()
	_menu.get_node("OpenContent/Tabs/BackpackTab").pressed.emit()

	assert_eq(_menu.get_node("BookSprite").animation, &"previous_page")
	assert_false(_menu.get_node("OpenContent/Pages/BackpackPage").visible)
	assert_false(_menu.get_node("OpenContent/Pages/SettingsPage").visible)
	assert_false(_menu.get_node("OpenContent/PageChrome/PageCorner").visible)

	_menu._on_animation_finished()

	assert_true(_menu.get_node("OpenContent/Pages/BackpackPage").visible)
	assert_false(_menu.get_node("OpenContent/Pages/SettingsPage").visible)
	assert_true(_menu.get_node("OpenContent/PageChrome/PageCorner").visible)
	assert_eq(_menu.get_node("OpenContent/Pages/BackpackPage/TitleLabel").text, "BackPack")


func test_unknown_page_falls_back_to_backpack() -> void:
	_menu._select_page("unknown")

	assert_true(_menu.get_node("OpenContent/Pages/BackpackPage").visible)
	assert_false(_menu.get_node("OpenContent/Pages/SettingsPage").visible)


func test_settings_page_has_pause_and_audio_controls() -> void:
	_menu._select_page("settings")

	assert_not_null(_menu.get_node("OpenContent/Pages/SettingsPage/Actions/ContinueButton"))
	assert_not_null(_menu.get_node("OpenContent/Pages/SettingsPage/Actions/SaveButton"))
	assert_not_null(_menu.get_node("OpenContent/Pages/SettingsPage/Actions/QuitButton"))
	assert_not_null(_menu.get_node("OpenContent/Pages/SettingsPage/AudioSettings/BgmSlider"))
	assert_not_null(_menu.get_node("OpenContent/Pages/SettingsPage/AudioSettings/SfxSlider"))


func test_continue_button_closes_book_menu_and_unpauses() -> void:
	_menu.visible = true
	_menu._is_open = true
	get_tree().paused = true

	_menu.get_node("OpenContent/Pages/SettingsPage/Actions/ContinueButton").pressed.emit()

	assert_false(_menu.visible)
	assert_false(get_tree().paused)


func test_save_button_is_inert() -> void:
	_menu.visible = true
	_menu._is_open = true
	get_tree().paused = true

	_menu.get_node("OpenContent/Pages/SettingsPage/Actions/SaveButton").pressed.emit()

	assert_true(_menu.visible)
	assert_true(get_tree().paused)


func test_open_and_close_do_not_apply_bgm_pause_blur() -> void:
	var fake_audio_manager := FakeAudioManager.new()
	add_child_autofree(fake_audio_manager)

	_menu.open()
	_menu.close()

	assert_eq(fake_audio_manager.blur_call_count, 0)

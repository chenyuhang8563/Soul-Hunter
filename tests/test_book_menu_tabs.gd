extends GutTest

const BookMenuScene := preload("res://Scenes/UI/book_menu.tscn")

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
	assert_true(_menu.get_node("OpenContent/Pages/BackpackPage").visible)
	assert_false(_menu.get_node("OpenContent/Pages/SettingsPage").visible)

	_menu._on_animation_finished()

	assert_false(_menu.get_node("OpenContent/Pages/BackpackPage").visible)
	assert_true(_menu.get_node("OpenContent/Pages/SettingsPage").visible)
	assert_eq(_menu.get_node("OpenContent/Pages/SettingsPage/TitleLabel").text, "Settings")


func test_backpack_tab_switches_back_to_backpack_page() -> void:
	_menu.get_node("OpenContent/Tabs/SettingsTab").pressed.emit()
	_menu._on_animation_finished()
	_menu.get_node("OpenContent/Tabs/BackpackTab").pressed.emit()

	assert_eq(_menu.get_node("BookSprite").animation, &"previous_page")
	assert_false(_menu.get_node("OpenContent/Pages/BackpackPage").visible)
	assert_true(_menu.get_node("OpenContent/Pages/SettingsPage").visible)

	_menu._on_animation_finished()

	assert_true(_menu.get_node("OpenContent/Pages/BackpackPage").visible)
	assert_false(_menu.get_node("OpenContent/Pages/SettingsPage").visible)
	assert_eq(_menu.get_node("OpenContent/Pages/BackpackPage/TitleLabel").text, "BackPack")


func test_unknown_page_falls_back_to_backpack() -> void:
	_menu._select_page("unknown")

	assert_true(_menu.get_node("OpenContent/Pages/BackpackPage").visible)
	assert_false(_menu.get_node("OpenContent/Pages/SettingsPage").visible)

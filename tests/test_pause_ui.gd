extends GutTest

const PauseUIScene := preload("res://Scenes/UI/pause_ui.tscn")
const ArenaHudScript := preload("res://Scenes/Arena/arena_hud.gd")

func test_pause_ui_layer_sits_above_arena_hud() -> void:
	var pause_ui: CanvasLayer = add_child_autofree(PauseUIScene.instantiate())
	var hud: ArenaHud = add_child_autofree(ArenaHudScript.new())
	await get_tree().process_frame

	assert_gt(
		pause_ui.layer,
		hud.layer,
		"Pause UI should render above the arena HUD so HUD controls cannot block its buttons."
	)

func test_arena_hud_root_does_not_consume_mouse_input() -> void:
	var hud: ArenaHud = add_child_autofree(ArenaHudScript.new())
	await get_tree().process_frame

	var root := hud.get_child(0) as Control
	assert_not_null(root, "Arena HUD should create a root Control.")
	if root == null:
		return

	assert_eq(
		root.mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
		"A display-only HUD root should ignore mouse input so lower UI layers remain clickable."
	)

func test_hidden_pause_ui_root_ignores_mouse_but_captures_when_open() -> void:
	var pause_ui: CanvasLayer = add_child_autofree(PauseUIScene.instantiate())
	await get_tree().process_frame

	var root := pause_ui.get_node("Control") as Control
	assert_not_null(root, "Pause UI should keep a root Control for input gating.")
	if root == null:
		return

	assert_eq(
		root.mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
		"When the pause panel is hidden, its fullscreen root should not block reward card clicks."
	)

	pause_ui.pause()

	assert_eq(
		root.mouse_filter,
		Control.MOUSE_FILTER_STOP,
		"When the pause panel opens, its fullscreen root should capture clicks."
	)

	pause_ui.unpause()

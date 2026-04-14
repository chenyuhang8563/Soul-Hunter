extends CanvasLayer

@export var pause_panel: Panel
@onready var root_control: Control = $Control

func _ready():
	_sync_input_capture()

func _process(_delta):
	if Input.is_action_just_pressed("pause"):
		if get_tree().paused:
			unpause()
		else:
			pause()

func _get_audio_manager() -> Node:
	return get_tree().get_first_node_in_group(&"audio_manager_service")

func pause():
	var audio_manager := _get_audio_manager()
	if audio_manager != null:
		audio_manager.set_bgm_pause_blur(true)

	get_tree().paused = true
	pause_panel.visible = true
	_sync_input_capture()

func unpause():
	get_tree().paused = false
	pause_panel.visible = false
	_sync_input_capture()

	var audio_manager := _get_audio_manager()
	if audio_manager != null:
		audio_manager.set_bgm_pause_blur(false)

func quit_game():
	get_tree().quit()

func _sync_input_capture() -> void:
	if root_control == null:
		return
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP if pause_panel.visible else Control.MOUSE_FILTER_IGNORE

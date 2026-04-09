extends CanvasLayer
class_name RunResultUI

signal restart_requested()

const SharedLabelSettings := preload("res://Resources/new_label_settings.tres")

var _panel: PanelContainer = null
var _title_label: Label = null
var _detail_label: Label = null
var _restart_button: Button = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	_build_ui()
	hide_ui()

func show_victory(total_waves: int) -> void:
	_build_ui()
	_title_label.text = "Victory"
	_detail_label.text = "You cleared all %d waves." % total_waves
	visible = true

func show_defeat(reached_wave: int) -> void:
	_build_ui()
	_title_label.text = "Defeat"
	_detail_label.text = "You fell on wave %d." % reached_wave
	visible = true

func hide_ui() -> void:
	visible = false

func _build_ui() -> void:
	if _panel != null and is_instance_valid(_panel):
		return

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	root.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(280.0, 160.0)
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.label_settings = SharedLabelSettings
	layout.add_child(_title_label)

	_detail_label = Label.new()
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.label_settings = SharedLabelSettings
	layout.add_child(_detail_label)

	_restart_button = Button.new()
	_restart_button.text = "Restart"
	_restart_button.focus_mode = Control.FOCUS_NONE
	_restart_button.add_theme_font_override("font", SharedLabelSettings.font)
	_restart_button.add_theme_font_size_override("font_size", SharedLabelSettings.font_size)
	_restart_button.pressed.connect(func() -> void:
		restart_requested.emit()
	)
	layout.add_child(_restart_button)

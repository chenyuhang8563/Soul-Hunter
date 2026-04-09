extends CanvasLayer
class_name RewardSelectionUI

signal card_selected(card_id: StringName)

const SharedLabelSettings := preload("res://Resources/new_label_settings.tres")

var _panel: PanelContainer = null
var _cards_box: HBoxContainer = null
var _title_label: Label = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build_ui()
	hide_ui()

func present_cards(cards: Array) -> void:
	_build_ui()
	for child in _cards_box.get_children():
		child.queue_free()

	for card in cards:
		var button := Button.new()
		button.custom_minimum_size = Vector2(88.0, 128.0)
		button.focus_mode = Control.FOCUS_NONE
		button.clip_contents = true
		button.add_theme_font_override("font", SharedLabelSettings.font)
		button.add_theme_font_size_override("font_size", SharedLabelSettings.font_size)
		button.pressed.connect(func() -> void:
			card_selected.emit(card.id)
		)

		var content := MarginContainer.new()
		content.set_anchors_preset(Control.PRESET_FULL_RECT)
		content.add_theme_constant_override("margin_left", 6)
		content.add_theme_constant_override("margin_top", 6)
		content.add_theme_constant_override("margin_right", 6)
		content.add_theme_constant_override("margin_bottom", 6)
		button.add_child(content)

		var layout := VBoxContainer.new()
		layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
		layout.add_theme_constant_override("separation", 4)
		content.add_child(layout)

		var title := Label.new()
		title.text = str(card.title)
		title.label_settings = SharedLabelSettings
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layout.add_child(title)

		var description := Label.new()
		description.text = str(card.description)
		description.label_settings = SharedLabelSettings
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		description.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layout.add_child(description)

		_cards_box.add_child(button)

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
	overlay.color = Color(0.0, 0.0, 0.0, 0.78)
	root.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(304.0, 154.0)
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	_title_label = Label.new()
	_title_label.text = "Choose Reward"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.label_settings = SharedLabelSettings
	layout.add_child(_title_label)

	_cards_box = HBoxContainer.new()
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_box.add_theme_constant_override("separation", 8)
	layout.add_child(_cards_box)

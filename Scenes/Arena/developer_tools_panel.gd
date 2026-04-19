extends CanvasLayer
class_name ArenaDeveloperToolsPanel

signal buff_value_changed(card_id, value)
signal jump_to_rest_requested(wave_index)
signal developer_mode_toggled(enabled)

const SharedLabelSettings := preload("res://Resources/new_label_settings.tres")

var _panel: PanelContainer = null
var _section_list: VBoxContainer = null
var _buff_section: VBoxContainer = null
var _wave_section: VBoxContainer = null
var _cheat_section: VBoxContainer = null
var _buff_selector: OptionButton = null
var _buff_slider: HSlider = null
var _buff_value_label: Label = null
var _wave_input: SpinBox = null
var _wave_jump_button: Button = null
var _developer_mode_toggle: CheckBox = null

var _arena_controller: ArenaRunController = null
var _run_modifier_controller: RunModifierController = null
var _buff_options: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 15
	_build_ui()
	_connect_developer_mode_signal()
	_sync_developer_mode_toggle()
	hide()

func bind(arena_controller: ArenaRunController, run_modifier_controller: RunModifierController, total_waves: int) -> void:
	_arena_controller = arena_controller
	_run_modifier_controller = run_modifier_controller
	set_total_waves(total_waves)
	_refresh_buff_options()
	_sync_developer_mode_toggle()

func set_total_waves(total_waves: int) -> void:
	_build_ui()
	var max_rest_wave := maxi(1, total_waves - 1)
	_wave_input.min_value = 1
	_wave_input.max_value = max_rest_wave
	if _wave_input.value < 1.0 or _wave_input.value > float(max_rest_wave):
		_wave_input.value = float(mini(1, max_rest_wave))

func _build_ui() -> void:
	if _panel != null and is_instance_valid(_panel):
		return

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var anchor := MarginContainer.new()
	anchor.anchor_left = 1.0
	anchor.anchor_top = 0.0
	anchor.anchor_right = 1.0
	anchor.anchor_bottom = 0.0
	anchor.offset_left = -188.0
	anchor.offset_top = 12.0
	anchor.offset_right = -12.0
	anchor.offset_bottom = 0.0
	root.add_child(anchor)

	_panel = PanelContainer.new()
	anchor.add_child(_panel)

	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 8)
	panel_margin.add_theme_constant_override("margin_top", 8)
	panel_margin.add_theme_constant_override("margin_right", 8)
	panel_margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(panel_margin)

	_section_list = VBoxContainer.new()
	_section_list.add_theme_constant_override("separation", 10)
	panel_margin.add_child(_section_list)

	_buff_section = _create_section("1. Buff Value")
	_section_list.add_child(_buff_section)

	_buff_selector = OptionButton.new()
	_buff_selector.focus_mode = Control.FOCUS_NONE
	_buff_selector.item_selected.connect(_on_buff_selected)
	_buff_section.add_child(_buff_selector)

	_buff_value_label = _create_small_label("")
	_buff_section.add_child(_buff_value_label)

	_buff_slider = HSlider.new()
	_buff_slider.step = 1.0
	_buff_slider.focus_mode = Control.FOCUS_NONE
	_buff_slider.value_changed.connect(_on_buff_slider_changed)
	_buff_section.add_child(_buff_slider)

	_wave_section = _create_section("2. Jump To Rest")
	_section_list.add_child(_wave_section)

	var wave_row := HBoxContainer.new()
	wave_row.add_theme_constant_override("separation", 6)
	_wave_section.add_child(wave_row)

	_wave_input = SpinBox.new()
	_wave_input.custom_minimum_size = Vector2(64.0, 0.0)
	_wave_input.step = 1.0
	_wave_input.rounded = true
	_wave_input.focus_mode = Control.FOCUS_NONE
	wave_row.add_child(_wave_input)

	_wave_jump_button = Button.new()
	_wave_jump_button.text = "Go"
	_wave_jump_button.focus_mode = Control.FOCUS_NONE
	_wave_jump_button.add_theme_font_override("font", SharedLabelSettings.font)
	_wave_jump_button.add_theme_font_size_override("font_size", SharedLabelSettings.font_size)
	_wave_jump_button.pressed.connect(func() -> void:
		jump_to_rest_requested.emit(int(roundi(_wave_input.value)))
	)
	wave_row.add_child(_wave_jump_button)

	var wave_hint := _create_small_label("Jump to the rest after wave X.")
	_wave_section.add_child(wave_hint)

	_cheat_section = _create_section("3. Cheat Mode")
	_section_list.add_child(_cheat_section)

	_developer_mode_toggle = CheckBox.new()
	_developer_mode_toggle.text = "Manual Enable"
	_developer_mode_toggle.focus_mode = Control.FOCUS_NONE
	_developer_mode_toggle.add_theme_font_override("font", SharedLabelSettings.font)
	_developer_mode_toggle.add_theme_font_size_override("font_size", SharedLabelSettings.font_size)
	_developer_mode_toggle.toggled.connect(func(enabled: bool) -> void:
		developer_mode_toggled.emit(enabled)
	)
	_cheat_section.add_child(_developer_mode_toggle)

	var cheat_hint := _create_small_label("P still works; this toggle stays in sync.")
	_cheat_section.add_child(cheat_hint)

func _create_section(title: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	var title_label := Label.new()
	title_label.text = title
	title_label.label_settings = SharedLabelSettings
	section.add_child(title_label)
	return section

func _create_small_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", SharedLabelSettings.font)
	label.add_theme_font_size_override("font_size", 5)
	return label

func _refresh_buff_options() -> void:
	_build_ui()
	_buff_selector.clear()
	_buff_options.clear()
	if _run_modifier_controller != null:
		_buff_options = _run_modifier_controller.get_developer_buff_options()
	for option in _buff_options:
		_buff_selector.add_item(String(option.get("label", "")))
	if _buff_options.is_empty():
		_buff_selector.disabled = true
		_buff_slider.editable = false
		_buff_value_label.text = "No developer buff options"
		return
	_buff_selector.disabled = false
	_buff_slider.editable = true
	_buff_selector.select(0)
	_apply_selected_buff_to_slider()

func _connect_developer_mode_signal() -> void:
	if DeveloperMode == null or not DeveloperMode.has_signal("mode_changed"):
		return
	var callable := Callable(self, "_on_developer_mode_changed")
	if not DeveloperMode.mode_changed.is_connected(callable):
		DeveloperMode.mode_changed.connect(callable)

func _sync_developer_mode_toggle() -> void:
	if _developer_mode_toggle == null:
		return
	_developer_mode_toggle.set_pressed_no_signal(DeveloperMode != null and DeveloperMode.is_enabled())

func _on_developer_mode_changed(enabled: bool) -> void:
	if _developer_mode_toggle != null:
		_developer_mode_toggle.set_pressed_no_signal(enabled)

func _on_buff_selected(_index: int) -> void:
	_apply_selected_buff_to_slider()

func _apply_selected_buff_to_slider() -> void:
	if _buff_options.is_empty():
		return
	var selected_option := _buff_options[_buff_selector.selected]
	var default_value := float(selected_option.get("default_value", 0.0))
	_buff_slider.min_value = 0.0
	_buff_slider.max_value = maxf(default_value * 5.0, 50.0)
	var card_id := selected_option.get("id", &"") as StringName
	var current_value := 0.0
	if _run_modifier_controller != null:
		current_value = _run_modifier_controller.get_developer_buff_value(card_id)
	_buff_slider.set_value_no_signal(current_value)
	_update_buff_value_label(current_value)

func _on_buff_slider_changed(value: float) -> void:
	if _buff_options.is_empty():
		return
	var selected_option := _buff_options[_buff_selector.selected]
	var card_id := selected_option.get("id", &"") as StringName
	_update_buff_value_label(value)
	buff_value_changed.emit(card_id, value)

func _update_buff_value_label(value: float) -> void:
	if _buff_options.is_empty():
		_buff_value_label.text = ""
		return
	var selected_option := _buff_options[_buff_selector.selected]
	var suffix := String(selected_option.get("suffix", ""))
	if value <= 0.0:
		_buff_value_label.text = "Off"
		return
	_buff_value_label.text = "Value: %s%s" % [_format_numeric_value(value), suffix]

func _format_numeric_value(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return str(value)

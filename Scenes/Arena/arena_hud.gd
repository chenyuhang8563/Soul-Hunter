extends CanvasLayer
class_name ArenaHud

const SharedLabelSettings := preload("res://Resources/new_label_settings.tres")

var _broadcast_root: VBoxContainer = null
var _wave_row: HBoxContainer = null
var _wave_label: Label = null
var _state_label: Label = null
var _rest_label: Label = null
var _buff_body_label: Label = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build_ui()
	set_rest_time(-1.0)
	set_buff_summary_text("")

func set_wave(wave_index: int, total_waves: int) -> void:
	_build_ui()
	_wave_label.text = "Wave %d / %d" % [wave_index, total_waves]

func set_state_text(text: String) -> void:
	_build_ui()
	_state_label.text = text

func set_rest_time(seconds: float) -> void:
	_build_ui()
	if seconds < 0.0:
		_rest_label.visible = false
		return
	_rest_label.visible = true
	_rest_label.text = "Rest: %.1fs" % seconds

func set_selected_buff_titles(titles: Array[String]) -> void:
	set_buff_summary_text(" ".join(titles))

func set_buff_summary_text(summary_text: String) -> void:
	_build_ui()
	_buff_body_label.text = summary_text
	_buff_body_label.visible = not summary_text.is_empty()

func _build_ui() -> void:
	if _wave_label != null and is_instance_valid(_wave_label):
		return

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_broadcast_root = VBoxContainer.new()
	_broadcast_root.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_broadcast_root.offset_left = 12.0
	_broadcast_root.offset_top = 5.0
	_broadcast_root.offset_right = -12.0
	_broadcast_root.offset_bottom = 80.0
	_broadcast_root.add_theme_constant_override("separation", 4)
	_broadcast_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_broadcast_root)

	_wave_row = HBoxContainer.new()
	_wave_row.add_theme_constant_override("separation", 10)
	_wave_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_broadcast_root.add_child(_wave_row)

	_wave_label = Label.new()
	_wave_label.text = "Wave 0 / 0"
	_wave_label.label_settings = SharedLabelSettings
	_wave_row.add_child(_wave_label)

	_buff_body_label = Label.new()
	_buff_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buff_body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_buff_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_buff_body_label.add_theme_font_override("font", SharedLabelSettings.font)
	_buff_body_label.add_theme_font_size_override("font_size", 5)
	_buff_body_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.45))
	_buff_body_label.add_theme_constant_override("shadow_offset_x", 1)
	_buff_body_label.add_theme_constant_override("shadow_offset_y", 1)
	_buff_body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_row.add_child(_buff_body_label)

	_state_label = Label.new()
	_state_label.text = "Prepare"
	_state_label.label_settings = SharedLabelSettings
	_broadcast_root.add_child(_state_label)

	_rest_label = Label.new()
	_rest_label.label_settings = SharedLabelSettings
	_broadcast_root.add_child(_rest_label)

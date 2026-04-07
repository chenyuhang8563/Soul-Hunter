extends CanvasLayer
class_name ArenaHud

const SharedLabelSettings := preload("res://Resources/new_label_settings.tres")

var _wave_label: Label = null
var _state_label: Label = null
var _rest_label: Label = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build_ui()
	set_rest_time(-1.0)

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

func _build_ui() -> void:
	if _wave_label != null and is_instance_valid(_wave_label):
		return

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.offset_left = 12.0
	margin.offset_top = 12.0
	margin.offset_right = 280.0
	margin.offset_bottom = 120.0
	root.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 4)
	margin.add_child(layout)

	_wave_label = Label.new()
	_wave_label.text = "Wave 0 / 0"
	_wave_label.label_settings = SharedLabelSettings
	layout.add_child(_wave_label)

	_state_label = Label.new()
	_state_label.text = "Prepare"
	_state_label.label_settings = SharedLabelSettings
	layout.add_child(_state_label)

	_rest_label = Label.new()
	_rest_label.label_settings = SharedLabelSettings
	layout.add_child(_rest_label)

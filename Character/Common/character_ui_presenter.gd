extends RefCounted
class_name CharacterUIPresenter

var hp_bar: ProgressBar
var posture_bar: ProgressBar

func setup(bar: ProgressBar, p_bar: ProgressBar = null) -> void:
	hp_bar = bar
	posture_bar = p_bar
	
	if posture_bar != null:
		posture_bar.max_value = 100.0
		posture_bar.value = 0.0
		posture_bar.visible = false

func update_health(current_health: float, max_health: float) -> void:
	if hp_bar == null:
		return
	hp_bar.max_value = max_health
	hp_bar.value = current_health

func update_posture(current_posture: float, max_posture: float) -> void:
	if posture_bar == null:
		return
	posture_bar.max_value = max_posture
	posture_bar.value = current_posture
	
	# Only show posture bar when there is some posture buildup
	posture_bar.visible = current_posture > 0.0

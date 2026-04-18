extends RefCounted
class_name CharacterUIPresenter

const DAMAGE_LAG_DURATION := 0.45
const DAMAGE_LAG_DELAY := 0.08

var hp_bar: ProgressBar
var hp_damage_bar: ProgressBar
var posture_bar: ProgressBar
var hp_damage_tween: Tween
var _displayed_health := -1.0
var _displayed_max_health := -1.0

func setup(bar: ProgressBar, p_bar: ProgressBar = null, damage_bar: ProgressBar = null) -> void:
	hp_bar = bar
	hp_damage_bar = damage_bar
	posture_bar = p_bar

	if hp_damage_bar != null and hp_bar != null:
		hp_damage_bar.max_value = hp_bar.max_value
		hp_damage_bar.value = hp_bar.value
	
	if posture_bar != null:
		posture_bar.max_value = 100.0
		posture_bar.value = 0.0
		posture_bar.visible = false

func update_health(current_health: float, max_health: float) -> void:
	if hp_bar == null:
		return
	hp_bar.max_value = max_health
	hp_bar.value = current_health
	if hp_damage_bar == null:
		_displayed_health = current_health
		_displayed_max_health = max_health
		return
	hp_damage_bar.max_value = max_health
	var should_sync_immediately := (
		_displayed_health < 0.0
		or not is_equal_approx(_displayed_max_health, max_health)
		or current_health >= _displayed_health
	)
	if should_sync_immediately:
		_stop_hp_damage_tween()
		hp_damage_bar.value = current_health
	else:
		_animate_damage_bar_to(current_health)
	_displayed_health = current_health
	_displayed_max_health = max_health

func update_posture(current_posture: float, max_posture: float) -> void:
	if posture_bar == null:
		return
	posture_bar.max_value = max_posture
	posture_bar.value = current_posture
	
	# Only show posture bar when there is some posture buildup
	posture_bar.visible = current_posture > 0.0

func _animate_damage_bar_to(target_health: float) -> void:
	_stop_hp_damage_tween()
	hp_damage_tween = hp_damage_bar.create_tween()
	hp_damage_tween.tween_interval(DAMAGE_LAG_DELAY)
	var tween_step := hp_damage_tween.tween_property(
		hp_damage_bar,
		"value",
		target_health,
		DAMAGE_LAG_DURATION
	)
	tween_step.set_trans(Tween.TRANS_SINE)
	tween_step.set_ease(Tween.EASE_OUT)

func _stop_hp_damage_tween() -> void:
	if hp_damage_tween != null:
		hp_damage_tween.kill()
		hp_damage_tween = null

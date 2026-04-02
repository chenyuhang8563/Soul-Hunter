extends Sprite2D

var _active_tween: Tween = null
var _release_cb: Callable = Callable()

func _ready() -> void:
	centered = false
	reset_state()

func play_once(world_position: Vector2, facing_left: bool, spec: Dictionary, release_cb: Callable) -> void:
	reset_state()
	_release_cb = release_cb
	global_position = world_position + _resolve_offset(spec, facing_left)
	rotation_degrees = _resolve_rotation(facing_left) + randf_range(-15.0, 15.0)
	var base_scale: Vector2 = spec.get("base_scale", Vector2.ONE)
	var start_scale := Vector2(base_scale.x * 0.58, base_scale.y)
	var end_scale := Vector2(base_scale.x * 1.18, base_scale.y)
	scale = start_scale
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	visible = true
	var duration := maxf(float(spec.get("duration", 0.1)), 0.01)
	var fade_in_duration := maxf(duration * 0.18, 0.01)
	var fade_out_duration := maxf(duration - fade_in_duration, 0.01)
	_active_tween = create_tween()
	_active_tween.tween_property(self, "modulate:a", 0.92, fade_in_duration)
	_active_tween.parallel().tween_property(self, "scale:x", end_scale.x, duration)
	_active_tween.tween_property(self, "modulate:a", 0.0, fade_out_duration)
	_active_tween.finished.connect(_on_playback_finished)

func reset_state() -> void:
	if _active_tween != null:
		_active_tween.kill()
		_active_tween = null
	centered = false
	_apply_left_pivot()
	visible = false
	position = Vector2.ZERO
	rotation = 0.0
	scale = Vector2.ONE
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	_release_cb = Callable()

func _apply_left_pivot() -> void:
	if texture == null:
		offset = Vector2.ZERO
		return
	offset = Vector2(0.0, -texture.get_height() * 0.5 + 5.0)

func _resolve_offset(_spec: Dictionary, _facing_left: bool) -> Vector2:
	return Vector2.ZERO

func _resolve_rotation(facing_left: bool) -> float:
	if facing_left:
		return 180.0
	return 0.0

func _on_playback_finished() -> void:
	var release_cb := _release_cb
	reset_state()
	if release_cb.is_valid():
		release_cb.call()

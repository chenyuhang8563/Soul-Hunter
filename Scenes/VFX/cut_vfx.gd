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
	rotation_degrees = _resolve_rotation(facing_left) + randf_range(-5.0, 5.0)
	var base_scale: Vector2 = spec.get("base_scale", Vector2.ONE)
	var length_scale := float(spec.get("length_scale", 1.0))
	scale = Vector2(base_scale.x * length_scale, base_scale.y)
	modulate = Color(1.0, 1.0, 1.0, 0.95)
	visible = true
	var duration := maxf(float(spec.get("duration", 0.1)) * 1.5, 0.01)
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.tween_property(self, "scale:x", scale.x * 1.35, duration)
	_active_tween.tween_property(self, "modulate:a", 0.0, duration)
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
	offset = Vector2(0.0, -texture.get_height() * 0.5)

func _resolve_offset(spec: Dictionary, facing_left: bool) -> Vector2:
	var slash_offset: Vector2 = spec.get("offset", Vector2.ZERO)
	if facing_left:
		slash_offset.x = -slash_offset.x
	return slash_offset

func _resolve_rotation(facing_left: bool) -> float:
	if facing_left:
		return 180.0
	return 0.0

func _on_playback_finished() -> void:
	var release_cb := _release_cb
	reset_state()
	if release_cb.is_valid():
		release_cb.call()

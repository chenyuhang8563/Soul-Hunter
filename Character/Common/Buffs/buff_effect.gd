extends RefCounted
class_name BuffEffect

enum StackPolicy {
	OVERRIDE,
	RESET_DURATION,
	STACK_VALUES,
	INDEPENDENT,
}

var buff_id: StringName = &""
var stack_key: StringName = &""
var display_name := ""
var duration := 0.0
var remaining_time := 0.0
var is_permanent := false
var tick_interval := 0.0
var stack_policy := StackPolicy.INDEPENDENT
var stack_count := 1
var max_stacks := 1

var _tick_accumulator := 0.0
var _cached_modifiers: Array = []
var _modifiers_dirty := true

func setup_duration(new_duration: float, permanent: bool = false) -> void:
	duration = maxf(0.0, new_duration)
	is_permanent = permanent
	reset_duration()

func reset_duration() -> void:
	remaining_time = duration
	_tick_accumulator = 0.0

func set_stack_count(new_stack_count: int) -> void:
	stack_count = clampi(new_stack_count, 1, max(1, max_stacks))
	mark_modifiers_dirty()

func mark_modifiers_dirty() -> void:
	_modifiers_dirty = true

func get_modifiers() -> Array:
	if _modifiers_dirty:
		_cached_modifiers = _build_cached_modifiers()
		_modifiers_dirty = false
	return _cached_modifiers

func build_modifiers() -> Array:
	return []

func on_applied(_context) -> void:
	pass

func on_removed(_context) -> void:
	pass

func on_tick(_context) -> void:
	pass

func on_refreshed(_incoming) -> void:
	pass

func on_stacked(_incoming) -> void:
	pass

func create_icon_instance() -> Node2D:
	return null

func process_tick(delta: float, context) -> void:
	if tick_interval <= 0.0:
		return
	_tick_accumulator += delta
	while _tick_accumulator >= tick_interval:
		_tick_accumulator -= tick_interval
		on_tick(context)

func process_duration(delta: float) -> void:
	if is_permanent:
		return
	remaining_time = maxf(0.0, remaining_time - delta)

func is_expired() -> bool:
	return not is_permanent and remaining_time <= 0.0

func refresh_from(incoming) -> void:
	on_refreshed(incoming)
	duration = incoming.duration
	is_permanent = incoming.is_permanent
	tick_interval = incoming.tick_interval
	max_stacks = incoming.max_stacks
	reset_duration()
	mark_modifiers_dirty()

func stack_from(incoming) -> void:
	duration = incoming.duration
	is_permanent = incoming.is_permanent
	tick_interval = incoming.tick_interval
	max_stacks = incoming.max_stacks
	stack_count = clampi(stack_count + incoming.stack_count, 1, max(1, max_stacks))
	on_stacked(incoming)
	reset_duration()
	mark_modifiers_dirty()

func _build_cached_modifiers() -> Array:
	var modifiers := build_modifiers()
	var result: Array = []
	for modifier in modifiers:
		if modifier == null:
			continue
		if modifier.has_method("duplicate_modifier"):
			result.append(modifier.duplicate_modifier())
	return result

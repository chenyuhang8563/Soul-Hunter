extends RefCounted
class_name BuffController

const BuffEffectScript := preload("res://Character/Common/Buffs/buff_effect.gd")
const StatModifierScript := preload("res://Character/Common/Buffs/stat_modifier.gd")

signal buff_added(buff)
signal buff_removed(buff)
signal stats_changed()

var context = null
var active_buffs: Array = []

var _stats_dirty := true
var _sequence_counter := 0
var _modifier_cache := {}

func setup(new_context) -> void:
	context = new_context
	_mark_stats_dirty()

func update(delta: float) -> void:
	if context == null or active_buffs.is_empty():
		return
	var expired: Array = []
	for buff in active_buffs:
		if buff == null:
			continue
		buff.process_tick(delta, context)
		buff.process_duration(delta)
		if buff.is_expired():
			expired.append(buff)
	if expired.is_empty():
		return
	for buff in expired:
		remove_buff(buff)

func add_buff(buff):
	if buff == null:
		return null
	if context == null:
		push_warning("BuffController.add_buff called before setup().")
		return null
	match buff.stack_policy:
		BuffEffectScript.StackPolicy.OVERRIDE:
			_remove_buffs_by_key(buff.stack_key)
		BuffEffectScript.StackPolicy.RESET_DURATION:
			var existing_refresh: Variant = _find_buff_by_key(buff.stack_key)
			if existing_refresh != null:
				existing_refresh.refresh_from(buff)
				_mark_stats_dirty()
				return existing_refresh
		BuffEffectScript.StackPolicy.STACK_VALUES:
			var existing_stack: Variant = _find_buff_by_key(buff.stack_key)
			if existing_stack != null:
				existing_stack.stack_from(buff)
				_mark_stats_dirty()
				return existing_stack
		BuffEffectScript.StackPolicy.INDEPENDENT:
			pass
	buff.on_applied(context)
	_register_buff(buff)
	return buff

func remove_buff(buff) -> bool:
	if buff == null:
		return false
	var index: int = active_buffs.find(buff)
	if index == -1:
		return false
	var removed: Variant = active_buffs[index]
	active_buffs.remove_at(index)
	if removed != null:
		removed.on_removed(context)
		buff_removed.emit(removed)
	_mark_stats_dirty()
	return true

func clear() -> void:
	var snapshot: Array = active_buffs.duplicate()
	for buff in snapshot:
		remove_buff(buff)

func get_stat_value(stat_id: StringName, fallback: float = 0.0) -> float:
	if context == null:
		return fallback
	if _stats_dirty:
		_rebuild_modifier_cache()
	var modifier_data: Dictionary = _modifier_cache.get(stat_id, {})
	var base_value: float = context.get_base_stat(stat_id, fallback)
	var additive_total: float = float(modifier_data.get("add", 0.0))
	var multiplier: float = float(modifier_data.get("mul", 1.0))
	return (base_value + additive_total) * multiplier

func has_buff(stack_key: StringName) -> bool:
	return _find_buff_by_key(stack_key) != null

func get_active_buffs() -> Array:
	return active_buffs.duplicate()

func _register_buff(buff) -> void:
	_sequence_counter += 1
	buff.set_meta("buff_sequence", _sequence_counter)
	active_buffs.append(buff)
	buff_added.emit(buff)
	_mark_stats_dirty()

func _remove_buffs_by_key(stack_key: StringName) -> void:
	if stack_key == &"":
		return
	var snapshot: Array = active_buffs.duplicate()
	for buff in snapshot:
		if buff != null and buff.stack_key == stack_key:
			remove_buff(buff)

func _find_buff_by_key(stack_key: StringName):
	if stack_key == &"":
		return null
	for buff in active_buffs:
		if buff != null and buff.stack_key == stack_key:
			return buff
	return null

func _mark_stats_dirty() -> void:
	_stats_dirty = true
	stats_changed.emit()

func _rebuild_modifier_cache() -> void:
	_modifier_cache.clear()
	var ordered_modifiers: Array[Dictionary] = []
	for buff in active_buffs:
		if buff == null:
			continue
		var buff_sequence: int = int(buff.get_meta("buff_sequence", 0))
		for modifier in buff.get_modifiers():
			if modifier == null:
				continue
			ordered_modifiers.append({
				"modifier": modifier,
				"mode": modifier.mode,
				"priority": modifier.priority,
				"sequence": buff_sequence,
			})
	ordered_modifiers.sort_custom(_sort_modifier_entries)
	for entry in ordered_modifiers:
		var modifier: Variant = entry.get("modifier")
		if modifier == null:
			continue
		var stat_id: StringName = modifier.stat_id
		if not _modifier_cache.has(stat_id):
			_modifier_cache[stat_id] = {
				"add": 0.0,
				"mul": 1.0,
			}
		var current: Dictionary = _modifier_cache[stat_id]
		if modifier.mode == StatModifierScript.Mode.ADD:
			current["add"] = float(current.get("add", 0.0)) + modifier.value
		else:
			current["mul"] = float(current.get("mul", 1.0)) * (1.0 + modifier.value)
		_modifier_cache[stat_id] = current
	_stats_dirty = false

func _sort_modifier_entries(left: Dictionary, right: Dictionary) -> bool:
	var left_mode: int = int(left.get("mode", 0))
	var right_mode: int = int(right.get("mode", 0))
	if left_mode != right_mode:
		return left_mode < right_mode
	var left_priority: int = int(left.get("priority", 0))
	var right_priority: int = int(right.get("priority", 0))
	if left_priority != right_priority:
		return left_priority < right_priority
	return int(left.get("sequence", 0)) < int(right.get("sequence", 0))

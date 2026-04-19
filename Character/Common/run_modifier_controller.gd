extends RefCounted
class_name RunModifierController

const RewardEffectDefinitionScript := preload("res://Global/Roguelike/reward_effect_definition.gd")
const RewardPoolResource := preload("res://Data/Roguelike/reward_pool_basic.tres")
const ModifierScript := preload("res://Character/Common/modifier.gd")
const DefenseDownBuffScript := preload("res://Character/Common/Buffs/defense_down_buff.gd")
const PossessionComboHasteBuffScript := preload("res://Character/Common/Buffs/possession_combo_haste_buff.gd")
const DASH_DAMAGE_GROUP := &"arena_enemy"
const DASH_DAMAGE_HALF_WIDTH := 12.0
const SKILL_EFFECT_LIFESTEAL_PERCENT := &"lifesteal_percent"
const SKILL_EFFECT_DASH_PATH_DAMAGE := &"dash_path_damage"
const SKILL_EFFECT_POSSESSION_COMBO_HASTE := &"possession_combo_haste"
const SKILL_EFFECT_DETACH_DASH_ARMOR_BREAK := &"detach_dash_armor_break"

signal stats_changed()

var _host: Object = null
var _selected_cards: Array[StringName] = []
var _selected_card_titles: Array[String] = []
var _hud_summary_tokens: Array[Dictionary] = []
var _hud_numeric_totals := {}
var _developer_buff_values := {}
var _developer_hud_summary_tokens: Array[Dictionary] = []
var _developer_hud_numeric_totals := {}
var _modifiers: Array = []
var _developer_modifiers: Array = []
var _lifesteal_percent := 0.0
var _developer_lifesteal_percent := 0.0
var _dash_path_damage := 0.0
var _has_possession_combo_haste := false
var _possession_combo_window := 3.0
var _possession_combo_required_count := 3
var _possession_combo_buff_duration := 4.0
var _possession_combo_buff_bonus := 15.0
var _recent_possession_timestamps: Array[float] = []
var _detach_dash_armor_break_duration := 0.0
var _detach_dash_armor_break_value := 0.0
var _next_dash_is_detach := false
var _stats_dirty := true
var _modifier_cache := {}

func setup(host: Object) -> void:
	_disconnect_host_signals()
	_host = host
	_connect_host_signals()
	_notify_stats_changed(true)

func reset() -> void:
	_selected_cards.clear()
	_selected_card_titles.clear()
	_hud_summary_tokens.clear()
	_hud_numeric_totals.clear()
	_developer_buff_values.clear()
	_developer_hud_summary_tokens.clear()
	_developer_hud_numeric_totals.clear()
	_modifiers.clear()
	_developer_modifiers.clear()
	_lifesteal_percent = 0.0
	_developer_lifesteal_percent = 0.0
	_dash_path_damage = 0.0
	_has_possession_combo_haste = false
	_possession_combo_window = 3.0
	_possession_combo_buff_duration = 4.0
	_possession_combo_buff_bonus = 15.0
	_recent_possession_timestamps.clear()
	_detach_dash_armor_break_duration = 0.0
	_detach_dash_armor_break_value = 0.0
	_next_dash_is_detach = false
	_mark_stats_dirty()
	_notify_stats_changed(true)

func apply_reward_card(card: Resource) -> void:
	if card == null:
		return

	_track_hud_summary_entry(card)
	if card.has_method("get"):
		var card_id = card.get("id") as StringName
		if card_id != &"":
			_selected_cards.append(card_id)
		var card_title := str(card.get("title"))
		if not card_title.is_empty():
			_selected_card_titles.append(card_title)

	var effects: Array = card.get("effects")
	var stat_effect_applied := false
	for effect in effects:
		stat_effect_applied = _apply_effect(effect) or stat_effect_applied
	if stat_effect_applied:
		_mark_stats_dirty()
		_notify_stats_changed()

func modify_stat_value(stat_id: StringName, base_value: float) -> float:
	if _stats_dirty:
		_rebuild_modifier_cache()
	var modifier_data: Dictionary = _modifier_cache.get(stat_id, {})
	var additive_total: float = float(modifier_data.get("add", 0.0))
	var multiplier: float = float(modifier_data.get("mul", 1.0))
	return (base_value + additive_total) * multiplier

func get_selected_cards() -> Array[StringName]:
	return _selected_cards.duplicate()

func get_selected_card_titles() -> Array[String]:
	return _selected_card_titles.duplicate()

func get_hud_buff_summary_text() -> String:
	var tokens: Array[String] = []
	_append_hud_summary_tokens(_hud_summary_tokens, _hud_numeric_totals, tokens)
	_append_hud_summary_tokens(_developer_hud_summary_tokens, _developer_hud_numeric_totals, tokens)
	return " ".join(tokens)

func get_lifesteal_percent() -> float:
	return _lifesteal_percent + _developer_lifesteal_percent

func get_dash_path_damage() -> float:
	return _dash_path_damage

func has_active_effects() -> bool:
	return not _selected_cards.is_empty() or not _developer_buff_values.is_empty() or not _modifiers.is_empty() or not _developer_modifiers.is_empty() or get_lifesteal_percent() > 0.0 or _dash_path_damage > 0.0 or _has_possession_combo_haste or _detach_dash_armor_break_duration > 0.0

func has_active_stat_modifiers() -> bool:
	return not _modifiers.is_empty() or not _developer_modifiers.is_empty()

func get_developer_buff_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for card in RewardPoolResource.cards:
		if not _supports_developer_buff(card):
			continue
		var card_id := card.get("id") as StringName
		var numeric_entry := _get_numeric_hud_entry(card_id)
		options.append({
			"id": card_id,
			"label": String(numeric_entry.get("label", str(card.get("title")))),
			"default_value": float(numeric_entry.get("value", 0.0)),
			"suffix": String(numeric_entry.get("suffix", "")),
		})
	return options

func get_developer_buff_value(card_id: StringName) -> float:
	return float(_developer_buff_values.get(card_id, 0.0))

func set_developer_buff_value(card_id: StringName, value: float) -> void:
	if card_id == &"":
		return
	if not _supports_developer_buff(_find_reward_card_by_id(card_id)):
		return
	var sanitized_value := maxf(0.0, value)
	if sanitized_value <= 0.0:
		_developer_buff_values.erase(card_id)
	else:
		_developer_buff_values[card_id] = sanitized_value
	_rebuild_developer_buff_state()
	_mark_stats_dirty()
	_notify_stats_changed(true)

func _track_hud_summary_entry(card: Resource) -> void:
	if not card.has_method("get"):
		return

	var card_id := card.get("id") as StringName
	var numeric_entry := _get_numeric_hud_entry(card_id)
	if not numeric_entry.is_empty():
		var category: StringName = numeric_entry.get("category", &"")
		if not _hud_numeric_totals.has(category):
			_hud_numeric_totals[category] = 0.0
			_hud_summary_tokens.append({
				"type": "numeric",
				"category": category,
				"label": numeric_entry.get("label", ""),
				"suffix": numeric_entry.get("suffix", ""),
			})
		_hud_numeric_totals[category] = float(_hud_numeric_totals.get(category, 0.0)) + float(numeric_entry.get("value", 0.0))
		return

	var card_title := str(card.get("title"))
	if not card_title.is_empty():
		_hud_summary_tokens.append({
			"type": "text",
			"text": card_title,
		})

func _get_numeric_hud_entry(card_id: StringName) -> Dictionary:
	match card_id:
		&"attack_up":
			return {"category": &"attack", "label": "Attack", "value": 10.0, "suffix": ""}
		&"lifesteal":
			return {"category": &"lifesteal", "label": "Lifesteal", "value": 20.0, "suffix": "%"}
		&"max_health_up":
			return {"category": &"vitality", "label": "Vitality", "value": 40.0, "suffix": ""}
		&"move_speed_up":
			return {"category": &"move_speed", "label": "Move Speed", "value": 15.0, "suffix": ""}
		&"attack_speed_up":
			return {"category": &"attack_speed", "label": "Attack Speed", "value": 15.0, "suffix": "%"}
		&"crit_chance_up":
			return {"category": &"crit_chance", "label": "Crit Chance", "value": 15.0, "suffix": "%"}
		&"defense_up":
			return {"category": &"defense", "label": "Defense", "value": 10.0, "suffix": ""}
	return {}

func _format_numeric_hud_entry(label: String, total: float, suffix: String) -> String:
	return "%s + %s%s" % [label, _format_hud_numeric_value(total), suffix]

func _format_hud_numeric_value(total: float) -> String:
	if is_equal_approx(total, roundf(total)):
		return str(int(roundf(total)))
	return str(total)

func _append_hud_summary_tokens(summary_tokens: Array[Dictionary], numeric_totals: Dictionary, output_tokens: Array[String]) -> void:
	for token in summary_tokens:
		var token_type := String(token.get("type", ""))
		if token_type == "numeric":
			var category: StringName = token.get("category", &"")
			var total := float(numeric_totals.get(category, 0.0))
			if total <= 0.0:
				continue
			output_tokens.append(_format_numeric_hud_entry(
				String(token.get("label", "")),
				total,
				String(token.get("suffix", ""))
			))
			continue
		output_tokens.append(String(token.get("text", "")))

func _apply_effect(effect: Resource) -> bool:
	if effect == null:
		return false

	match effect.effect_type:
		RewardEffectDefinitionScript.EffectType.STAT_ADD:
			_modifiers.append(ModifierScript.new(effect.stat_id, effect.value, ModifierScript.Mode.ADD, 0))
			return true
		RewardEffectDefinitionScript.EffectType.SKILL:
			if not _apply_skill_effect(effect) and effect.effect_id == &"":
				_lifesteal_percent += effect.value
		_:
			var legacy_effect_type := int(effect.effect_type)
			if legacy_effect_type == 1:
				_lifesteal_percent += effect.value
			elif legacy_effect_type == 2:
				_dash_path_damage += effect.value
	return false

func _apply_skill_effect(effect: Resource) -> bool:
	var skill_effect_id: StringName = effect.effect_id
	match skill_effect_id:
		SKILL_EFFECT_LIFESTEAL_PERCENT, &"lifesteal":
			_lifesteal_percent += effect.value
			return true
		SKILL_EFFECT_DASH_PATH_DAMAGE, &"dash_slash":
			_dash_path_damage += effect.value
			return true
		SKILL_EFFECT_POSSESSION_COMBO_HASTE:
			_has_possession_combo_haste = true
			if effect.aux_value > 0.0:
				_possession_combo_window = effect.aux_value
			if effect.duration > 0.0:
				_possession_combo_buff_duration = effect.duration
			if effect.value > 0.0:
				_possession_combo_buff_bonus = effect.value
			return true
		SKILL_EFFECT_DETACH_DASH_ARMOR_BREAK:
			_detach_dash_armor_break_value = effect.value
			_detach_dash_armor_break_duration = maxf(effect.duration, 0.0)
			return true
	return false

func record_possession(now_seconds: float = -1.0) -> void:
	if not _has_possession_combo_haste or _host == null:
		return
	var timestamp := now_seconds if now_seconds >= 0.0 else float(Time.get_ticks_msec()) / 1000.0
	_recent_possession_timestamps.append(timestamp)
	_prune_recent_possession_timestamps(timestamp)
	if _recent_possession_timestamps.size() < _possession_combo_required_count:
		return
	_recent_possession_timestamps.clear()
	if not _host.has_method("add_buff"):
		return
	var buff = PossessionComboHasteBuffScript.new()
	buff.move_speed_bonus = _possession_combo_buff_bonus / 100.0
	buff.attack_speed_bonus = _possession_combo_buff_bonus / 100.0
	buff.setup_duration(_possession_combo_buff_duration)
	_host.call("add_buff", buff)

func mark_next_dash_as_detach() -> void:
	_next_dash_is_detach = true

func _prune_recent_possession_timestamps(reference_time: float) -> void:
	var cutoff := reference_time - _possession_combo_window
	var kept: Array[float] = []
	for timestamp in _recent_possession_timestamps:
		if timestamp >= cutoff:
			kept.append(timestamp)
	_recent_possession_timestamps = kept

func _mark_stats_dirty() -> void:
	_stats_dirty = true

func _notify_stats_changed(force_emit: bool = false) -> void:
	if force_emit or has_active_stat_modifiers():
		stats_changed.emit()

func _rebuild_modifier_cache() -> void:
	_modifier_cache.clear()
	var ordered_modifiers: Array[Dictionary] = []
	for modifier_group in [_modifiers, _developer_modifiers]:
		for modifier in modifier_group:
			if modifier == null:
				continue
			ordered_modifiers.append({
				"modifier": modifier,
				"mode": modifier.mode,
				"priority": modifier.priority,
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
		if modifier.mode == ModifierScript.Mode.ADD:
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
	return int(left.get("priority", 0)) < int(right.get("priority", 0))

func _connect_host_signals() -> void:
	if _host == null:
		return
	if _host.has_signal("damage_dealt"):
		var damage_callable := Callable(self, "_on_host_damage_dealt")
		if not _host.is_connected("damage_dealt", damage_callable):
			_host.connect("damage_dealt", damage_callable)
	if _host.has_signal("dash_finished"):
		var dash_callable := Callable(self, "_on_host_dash_finished")
		if not _host.is_connected("dash_finished", dash_callable):
			_host.connect("dash_finished", dash_callable)

func _disconnect_host_signals() -> void:
	if _host == null:
		return
	if _host.has_signal("damage_dealt"):
		var damage_callable := Callable(self, "_on_host_damage_dealt")
		if _host.is_connected("damage_dealt", damage_callable):
			_host.disconnect("damage_dealt", damage_callable)
	if _host.has_signal("dash_finished"):
		var dash_callable := Callable(self, "_on_host_dash_finished")
		if _host.is_connected("dash_finished", dash_callable):
			_host.disconnect("dash_finished", dash_callable)

func _on_host_damage_dealt(_target: Object, final_damage: float) -> void:
	if _host == null or _lifesteal_percent <= 0.0 or final_damage <= 0.0:
		return
	if _host.has_method("heal"):
		_host.heal(final_damage * (_lifesteal_percent / 100.0))

func _on_host_dash_finished(start_position: Vector2, end_position: Vector2) -> void:
	if _next_dash_is_detach:
		_next_dash_is_detach = false
		_apply_detach_dash_armor_break(start_position, end_position)
	_apply_dash_path_damage(start_position, end_position)

func _apply_dash_path_damage(start_position: Vector2, end_position: Vector2) -> void:
	if _host == null or _dash_path_damage <= 0.0:
		return
	if not (_host is Node):
		return

	var host_node := _host as Node
	var tree := host_node.get_tree()
	if tree == null:
		return

	var dash_targets: Array = tree.get_nodes_in_group(DASH_DAMAGE_GROUP)
	for target in dash_targets:
		if not _is_dash_damage_target(target):
			continue
		var target_node := target as Node2D
		if _distance_to_segment(target_node.global_position, start_position, end_position) > DASH_DAMAGE_HALF_WIDTH:
			continue
		target_node.call("apply_damage", _dash_path_damage, _resolve_damage_source())

func _apply_detach_dash_armor_break(start_position: Vector2, end_position: Vector2) -> void:
	if _detach_dash_armor_break_duration <= 0.0 or _host == null:
		return
	if not (_host is Node):
		return

	var host_node := _host as Node
	var tree := host_node.get_tree()
	if tree == null:
		return

	var dash_targets: Array = tree.get_nodes_in_group(DASH_DAMAGE_GROUP)
	for target in dash_targets:
		if not _is_dash_damage_target(target):
			continue
		var target_node := target as Node2D
		if _distance_to_segment(target_node.global_position, start_position, end_position) > DASH_DAMAGE_HALF_WIDTH:
			continue
		if not target.has_method("add_buff"):
			continue
		var buff = DefenseDownBuffScript.new()
		buff.defense_penalty = _detach_dash_armor_break_value
		buff.setup_duration(_detach_dash_armor_break_duration)
		target.call("add_buff", buff)

func _is_dash_damage_target(target: Object) -> bool:
	if not (target is Node2D):
		return false
	if target == _host:
		return false
	if target.has_method("is_alive") and not bool(target.call("is_alive")):
		return false
	if not target.has_method("apply_damage"):
		return false
	if _host != null and _host.has_method("get_team_id") and target.has_method("get_team_id"):
		if int(_host.call("get_team_id")) == int(target.call("get_team_id")):
			return false
	return true

func _distance_to_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> float:
	var segment := segment_end - segment_start
	var segment_length_squared := segment.length_squared()
	if is_zero_approx(segment_length_squared):
		return point.distance_to(segment_start)

	var projected := clampf((point - segment_start).dot(segment) / segment_length_squared, 0.0, 1.0)
	var closest_point := segment_start + segment * projected
	return point.distance_to(closest_point)

func _resolve_damage_source() -> CharacterBody2D:
	if _host is CharacterBody2D:
		return _host as CharacterBody2D
	return null

func _rebuild_developer_buff_state() -> void:
	_developer_hud_summary_tokens.clear()
	_developer_hud_numeric_totals.clear()
	_developer_modifiers.clear()
	_developer_lifesteal_percent = 0.0
	for card in RewardPoolResource.cards:
		if card == null or not card.has_method("get"):
			continue
		var card_id := card.get("id") as StringName
		if not _developer_buff_values.has(card_id):
			continue
		if not _supports_developer_buff(card):
			continue
		var display_value := float(_developer_buff_values.get(card_id, 0.0))
		if display_value <= 0.0:
			continue
		var numeric_entry := _get_numeric_hud_entry(card_id)
		var default_display_value := float(numeric_entry.get("value", 0.0))
		if default_display_value <= 0.0:
			continue
		var category: StringName = numeric_entry.get("category", &"")
		_developer_hud_numeric_totals[category] = display_value
		_developer_hud_summary_tokens.append({
			"type": "numeric",
			"category": category,
			"label": String(numeric_entry.get("label", "")),
			"suffix": String(numeric_entry.get("suffix", "")),
		})
		var scale := display_value / default_display_value
		for effect in card.get("effects"):
			if effect == null:
				continue
			var scaled_value := float(effect.value) * scale
			if int(effect.effect_type) == int(RewardEffectDefinitionScript.EffectType.STAT_ADD):
				_developer_modifiers.append(ModifierScript.new(effect.stat_id, scaled_value, ModifierScript.Mode.ADD, 0))
				continue
			if int(effect.effect_type) == int(RewardEffectDefinitionScript.EffectType.SKILL):
				if effect.effect_id == SKILL_EFFECT_LIFESTEAL_PERCENT or effect.effect_id == &"lifesteal":
					_developer_lifesteal_percent += scaled_value

func _find_reward_card_by_id(card_id: StringName) -> Resource:
	for card in RewardPoolResource.cards:
		if card != null and card.has_method("get") and card.get("id") == card_id:
			return card
	return null

func _supports_developer_buff(card: Resource) -> bool:
	if card == null or not card.has_method("get"):
		return false
	var card_id := card.get("id") as StringName
	var numeric_entry := _get_numeric_hud_entry(card_id)
	if numeric_entry.is_empty():
		return false
	var effects: Array = card.get("effects")
	if effects.is_empty():
		return false
	for effect in effects:
		if effect == null:
			return false
		if int(effect.effect_type) == int(RewardEffectDefinitionScript.EffectType.STAT_ADD):
			continue
		if int(effect.effect_type) == int(RewardEffectDefinitionScript.EffectType.SKILL) and (effect.effect_id == SKILL_EFFECT_LIFESTEAL_PERCENT or effect.effect_id == &"lifesteal"):
			continue
		return false
	return true

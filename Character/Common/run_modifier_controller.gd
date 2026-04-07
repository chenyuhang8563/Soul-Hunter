extends RefCounted
class_name RunModifierController

const RewardEffectDefinitionScript := preload("res://Global/Roguelike/reward_effect_definition.gd")
const DASH_DAMAGE_GROUP := &"arena_enemy"
const DASH_DAMAGE_HALF_WIDTH := 12.0

var _host: Object = null
var _selected_cards: Array[StringName] = []
var _stat_additions: Dictionary = {}
var _lifesteal_percent := 0.0
var _dash_path_damage := 0.0

func setup(host: Object) -> void:
	_disconnect_host_signals()
	_host = host
	_connect_host_signals()

func reset() -> void:
	_selected_cards.clear()
	_stat_additions.clear()
	_lifesteal_percent = 0.0
	_dash_path_damage = 0.0

func apply_reward_card(card: Resource) -> void:
	if card == null:
		return

	if card.has_method("get"):
		var card_id = card.get("id") as StringName
		if card_id != &"":
			_selected_cards.append(card_id)

	var effects: Array = card.get("effects")
	for effect in effects:
		_apply_effect(effect)

func modify_stat_value(stat_id: StringName, base_value: float) -> float:
	return base_value + float(_stat_additions.get(stat_id, 0.0))

func get_selected_cards() -> Array[StringName]:
	return _selected_cards.duplicate()

func get_lifesteal_percent() -> float:
	return _lifesteal_percent

func get_dash_path_damage() -> float:
	return _dash_path_damage

func _apply_effect(effect: Resource) -> void:
	if effect == null:
		return

	match effect.effect_type:
		RewardEffectDefinitionScript.EffectType.STAT_ADD:
			var current_bonus := float(_stat_additions.get(effect.stat_id, 0.0))
			_stat_additions[effect.stat_id] = current_bonus + effect.value
		RewardEffectDefinitionScript.EffectType.LIFESTEAL_PERCENT:
			_lifesteal_percent += effect.value
		RewardEffectDefinitionScript.EffectType.DASH_PATH_DAMAGE:
			_dash_path_damage += effect.value

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

func _on_host_dash_finished(_start_position: Vector2, _end_position: Vector2) -> void:
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
		if _distance_to_segment(target_node.global_position, _start_position, _end_position) > DASH_DAMAGE_HALF_WIDTH:
			continue
		target_node.call("apply_damage", _dash_path_damage, _resolve_damage_source())

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

extends "res://Character/Common/simple_melee_attack_module.gd"
class_name ArcherAttackModule

const ARROW_SCENE := preload("res://Scenes/arrow.tscn")

func _init() -> void:
	configure({
		"light_attack_duration": 0.90,
		"hard_attack_duration": 1.20,
		"light_attack_hit_delay": 0.50,
		"hard_attack_hit_delay": 0.70,
		"melee_attack_range": 40.0,
		"light_attack_probability": 0.65,
	})

func start_attack(light_attack: bool) -> void:
	if not can_start_attack():
		return
	if light_attack:
		_begin_attack("light_attack", _get_light_attack_duration(light_attack_duration), true, true, false, false)
		_queue_stat_damage_event(light_attack_hit_delay, &"light_attack_damage", stats.light_attack_damage, melee_attack_range, false, true)
	else:
		_begin_attack("hard_attack", hard_attack_duration, false, false, true, false)
		_queue_stat_damage_event(hard_attack_hit_delay, &"hard_attack_damage", stats.hard_attack_damage, melee_attack_range, false, true)

func _handle_damage_event_override(event: Dictionary) -> bool:
	if owner == null or sprite == null:
		return true
	var arrow_instance = ARROW_SCENE.instantiate()
	var facing_dir := Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
	var spawn_pos := owner.global_position + Vector2(0.0, -2.0) + facing_dir * 10.0
	arrow_instance.position = spawn_pos
	var damage_result := _resolve_damage_event_result(event)
	arrow_instance.setup(facing_dir, float(damage_result.get("damage", 0.0)), owner, bool(damage_result.get("critical_hit", false)))
	var spawn_parent := owner.get_parent()
	if spawn_parent == null:
		spawn_parent = owner.get_tree().current_scene
	if spawn_parent != null:
		spawn_parent.add_child(arrow_instance)
	return true

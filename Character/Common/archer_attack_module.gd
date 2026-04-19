extends "res://Character/Common/simple_melee_attack_module.gd"
class_name ArcherAttackModule

const ARROW_SCENE := preload("res://Scenes/arrow.tscn")
const EXPLOSIVE_LIGHT_SHOT_INTERVAL := 3
const EXPLOSIVE_ARROW_DAMAGE := 50.0
const EXPLOSIVE_ARROW_RADIUS := 40.0

var _projectile_released := false
var _light_attack_arrow_count := 0

func _init() -> void:
	configure({
		"light_attack_duration": 0.90,
		"hard_attack_duration": 1.20,
		"melee_attack_range": 40.0,
		"light_attack_probability": 0.65,
	})

func start_attack(light_attack: bool) -> void:
	if not can_start_attack():
		return
	if light_attack:
		_begin_attack("light_attack", _get_light_attack_duration(light_attack_duration), true, true, false, false)
	else:
		_begin_attack("hard_attack", hard_attack_duration, false, false, true, false)
	
func _on_attack_started(_attack_name: String) -> void:
	_projectile_released = false

func _on_attack_finished(_attack_name: String) -> void:
	_projectile_released = false

func _on_force_stop() -> void:
	_projectile_released = false

func on_animation_event(event_name: StringName) -> void:
	if event_name != &"release_projectile" or _projectile_released:
		return
	match current_attack:
		"light_attack":
			_light_attack_arrow_count += 1
			var projectile_config := {}
			if _light_attack_arrow_count % EXPLOSIVE_LIGHT_SHOT_INTERVAL == 0:
				projectile_config = {
					"explosive": true,
					"explosion_damage": EXPLOSIVE_ARROW_DAMAGE,
					"explosion_radius": EXPLOSIVE_ARROW_RADIUS,
				}
			_spawn_arrow(&"light_attack_damage", stats.light_attack_damage, projectile_config)
		"hard_attack":
			_spawn_arrow(&"hard_attack_damage", stats.hard_attack_damage)
		_:
			return
	_projectile_released = true

func _spawn_arrow(stat_id: StringName, fallback_damage: float, projectile_config: Dictionary = {}) -> void:
	if owner == null or sprite == null:
		return
	var arrow_instance = ARROW_SCENE.instantiate()
	var facing_dir := Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
	var spawn_pos := owner.global_position + Vector2(0.0, -2.0) + facing_dir * 10.0
	arrow_instance.position = spawn_pos
	var damage_result := _resolve_damage_event_result({
		"stat_id": stat_id,
		"damage": fallback_damage,
	})
	arrow_instance.setup(
		facing_dir,
		float(damage_result.get("damage", 0.0)),
		owner,
		bool(damage_result.get("critical_hit", false)),
		projectile_config
	)
	var spawn_parent := owner.get_parent()
	if spawn_parent == null:
		spawn_parent = owner.get_tree().current_scene
	if spawn_parent != null:
		spawn_parent.add_child(arrow_instance)

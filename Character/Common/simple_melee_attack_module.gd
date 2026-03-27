extends "res://Character/Common/attack_module_base.gd"
class_name SimpleMeleeAttackModule

var light_attack_duration := 0.60
var hard_attack_duration := 0.60
var light_attack_hit_delay := 0.40
var hard_attack_hit_delay := 0.45
var melee_attack_range := 42.0
var light_attack_probability := 0.6

func configure(config: Dictionary) -> SimpleMeleeAttackModule:
	light_attack_duration = float(config.get("light_attack_duration", light_attack_duration))
	hard_attack_duration = float(config.get("hard_attack_duration", hard_attack_duration))
	light_attack_hit_delay = float(config.get("light_attack_hit_delay", light_attack_hit_delay))
	hard_attack_hit_delay = float(config.get("hard_attack_hit_delay", hard_attack_hit_delay))
	melee_attack_range = float(config.get("melee_attack_range", melee_attack_range))
	light_attack_probability = float(config.get("light_attack_probability", light_attack_probability))
	return self

func setup(
		host: CharacterBody2D,
		sprite_node: Sprite2D = null,
		tree: AnimationTree = null,
		player: AnimationPlayer = null,
		_hitbox: Area2D = null,
		_hitbox_shape: CollisionShape2D = null,
		character_stats: CharacterStats = null,
		cooldown: float = 0.30,
		audio_service_node: Node = null
) -> void:
	param_is_any_attack = ""
	param_is_bow_attack = ""
	param_is_attack_combined = PARAM_IS_ATTACK_COMBINED
	super.setup(host, sprite_node, tree, player, _hitbox, _hitbox_shape, character_stats, cooldown, audio_service_node)

func start_ai_attack() -> bool:
	if not can_start_attack():
		return false
	start_attack(randf() < light_attack_probability)
	return true

func start_attack(light_attack: bool) -> void:
	if not can_start_attack():
		return
	if light_attack:
		_begin_attack("light_attack", _get_light_attack_duration(light_attack_duration), true, true, false, false)
		_queue_stat_damage_event(light_attack_hit_delay, &"light_attack_damage", stats.light_attack_damage, melee_attack_range, true, true)
	else:
		_begin_attack("hard_attack", hard_attack_duration, false, false, true, false)
		_queue_stat_damage_event(hard_attack_hit_delay, &"hard_attack_damage", stats.hard_attack_damage, melee_attack_range, true, true)

func reset() -> void:
	force_stop()
	attack_cooldown_left = 0.0

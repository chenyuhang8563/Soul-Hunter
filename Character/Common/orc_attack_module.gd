extends "res://Character/Common/attack_module_base.gd"
class_name OrcAttackModule

const LIGHT_ATTACK_DURATION := 0.60
const HARD_ATTACK_DURATION := 0.60
const LIGHT_ATTACK_HIT_DELAY := 0.40
const HARD_ATTACK_HIT_DELAY := 0.45

const MELEE_ATTACK_RANGE := 42.0

func setup(
		host: CharacterBody2D,
		sprite_node: Sprite2D = null,
		tree: AnimationTree = null,
		_player: AnimationPlayer = null,
		_hitbox: Area2D = null,
		_hitbox_shape: CollisionShape2D = null,
		character_stats: CharacterStats = null,
		cooldown: float = 0.30
) -> void:
	param_is_any_attack = ""
	param_is_bow_attack = ""
	param_is_attack_combined = PARAM_IS_ATTACK_COMBINED
	super.setup(host, sprite_node, tree, _player, _hitbox, _hitbox_shape, character_stats, cooldown)

func update(delta: float, target: Node2D = null, in_scope: bool = false) -> void:
	super.update(delta, target, in_scope)

func start_ai_attack() -> bool:
	if not can_start_attack():
		return false
	
	var rand := randf()
	if rand < 0.6: # 60% probability for light attack
		start_attack(true)
	else: # 40% probability for hard attack
		start_attack(false)
	
	return true

func start_attack(light_attack: bool) -> void:
	if not can_start_attack():
		return
	if light_attack:
		_begin_attack("light_attack", LIGHT_ATTACK_DURATION, true, true, false, false)
		_queue_damage_event(LIGHT_ATTACK_HIT_DELAY, stats.light_attack_damage, MELEE_ATTACK_RANGE, true, true)
	else:
		_begin_attack("hard_attack", HARD_ATTACK_DURATION, false, false, true, false)
		_queue_damage_event(HARD_ATTACK_HIT_DELAY, stats.hard_attack_damage, MELEE_ATTACK_RANGE, true, true)

func reset() -> void:
	force_stop()
	attack_cooldown_left = 0.0

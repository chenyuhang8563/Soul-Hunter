extends "res://Character/Common/attack_module_base.gd"
class_name SoldierAttackModule

const LIGHT_ATTACK_DURATION := 0.60
const HARD_ATTACK_DURATION := 0.60
const ULTIMATE_ATTACK_DURATION := 0.80
const ATTACK_COOLDOWN := 0.30
const LIGHT_ATTACK_HIT_DELAY := 0.40
const HARD_ATTACK_HIT_DELAY := 0.45
const ULTIMATE_ATTACK_HIT_DELAY := 0.65
const MELEE_ATTACK_RANGE := 42.0
const ULTIMATE_ATTACK_RANGE := 64.0
const ARROW_SCENE := preload("res://Scenes/arrow.tscn")

func setup(
		host: CharacterBody2D,
		sprite_node: Sprite2D = null,
		tree: AnimationTree = null,
		player: AnimationPlayer = null,
		_hitbox: Area2D = null,
		_hitbox_shape: CollisionShape2D = null,
		character_stats: CharacterStats = null,
		cooldown: float = ATTACK_COOLDOWN,
		audio_service_node: Node = null
) -> void:
	super.setup(host, sprite_node, tree, player, _hitbox, _hitbox_shape, character_stats, cooldown, audio_service_node)

func update(delta: float, target: Node2D = null, in_scope: bool = false) -> void:
	super.update(delta, target, in_scope)

func try_start_from_input() -> void:
	if not can_start_attack():
		return
	if _action_just_pressed("ultimate_attack"):
		_start_ultimate_attack()
	elif _action_just_pressed("hard_attack"):
		_start_hard_attack()
	elif _action_just_pressed("light_attack"):
		_start_light_attack()

func start_ai_attack() -> bool:
	if not can_start_attack():
		return false
	
	var rand := randf()
	if rand < 0.5: # 50% probability for light attack
		_start_light_attack()
	elif rand < 0.8: # 30% probability for hard attack
		_start_hard_attack()
	else: # 20% probability for ultimate attack
		_start_ultimate_attack()
	
	return true

func _action_just_pressed(action_name: StringName) -> bool:
	return InputMap.has_action(action_name) and Input.is_action_just_pressed(action_name)

func _start_light_attack() -> void:
	_begin_attack("light_attack", _get_light_attack_duration(LIGHT_ATTACK_DURATION), true, true, false, false)
	_queue_stat_damage_event(LIGHT_ATTACK_HIT_DELAY, &"light_attack_damage", stats.light_attack_damage, MELEE_ATTACK_RANGE, true, true)

func _start_hard_attack() -> void:
	_begin_attack("hard_attack", HARD_ATTACK_DURATION, false, false, true, false)
	_queue_stat_damage_event(HARD_ATTACK_HIT_DELAY, &"hard_attack_damage", stats.hard_attack_damage, MELEE_ATTACK_RANGE, true, true)

func _start_ultimate_attack() -> void:
	_begin_attack("ultimate_attack", ULTIMATE_ATTACK_DURATION, false, false, false, true)
	_queue_stat_damage_event(ULTIMATE_ATTACK_HIT_DELAY, &"ultimate_attack", stats.ultimate_attack, ULTIMATE_ATTACK_RANGE, false, false)

func _handle_damage_event_override(event: Dictionary) -> bool:
	if current_attack == "ultimate_attack":
		if owner == null:
			return true
		
		var arrow_instance = ARROW_SCENE.instantiate()
		var facing_dir := Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
		
		var spawn_pos = owner.global_position + Vector2(0, 0) + facing_dir * 10
		arrow_instance.position = spawn_pos
		arrow_instance.setup(facing_dir, _resolve_damage_event_amount(event), owner)
		
		owner.get_parent().add_child(arrow_instance)
		return true
	return false

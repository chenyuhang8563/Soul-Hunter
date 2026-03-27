class_name AttackModuleBase
extends RefCounted

const PARAM_IS_LIGHT_ATTACK := "parameters/attack_state_machine/conditions/is_light_attack"
const PARAM_IS_HARD_ATTACK := "parameters/attack_state_machine/conditions/is_hard_attack"
const PARAM_IS_BOW_ATTACK := "parameters/attack_state_machine/conditions/is_bow_attack"
const PARAM_IS_ANY_ATTACK := "parameters/conditions/is_any_attack"
const PARAM_ATTACK_FINISHED := "parameters/conditions/attack_finished"
const PARAM_IS_ATTACK_COMBINED := "parameters/conditions/is_light_attack or is_hard_attack"
const PLAYER_LIGHT_ATTACK_DURATION_MULTIPLIER := 0.8

var owner: CharacterBody2D
var sprite: Sprite2D
var animation_tree: AnimationTree
var stats: CharacterStats
var audio_service: Node = null

var attack_cooldown := 0.30
var attack_cooldown_left := 0.0
var attack_time_left := 0.0
var attack_duration := 0.0
var current_attack := ""
var current_attack_movable := true
var damage_events: Array[Dictionary] = []
var current_target: Node2D
var current_target_in_scope := false

var param_is_light_attack := PARAM_IS_LIGHT_ATTACK
var param_is_hard_attack := PARAM_IS_HARD_ATTACK
var param_is_bow_attack := PARAM_IS_BOW_ATTACK
var param_is_any_attack := PARAM_IS_ANY_ATTACK
var param_attack_finished := PARAM_ATTACK_FINISHED
var param_is_attack_combined := ""

var parry_window_start := 0.30
var parry_window_end := 0.40

func setup(
		host: CharacterBody2D,
		sprite_node: Sprite2D = null,
		tree: AnimationTree = null,
		_player: AnimationPlayer = null,
		_hitbox: Area2D = null,
		_hitbox_shape: CollisionShape2D = null,
		character_stats: CharacterStats = null,
		cooldown: float = 0.30,
		audio_service_node: Node = null
) -> void:
	owner = host
	sprite = sprite_node
	animation_tree = tree
	stats = character_stats
	audio_service = audio_service_node
	attack_cooldown = maxf(0.0, cooldown)
	attack_cooldown_left = 0.0
	attack_time_left = 0.0
	attack_duration = 0.0
	current_attack = ""
	current_attack_movable = true
	damage_events.clear()
	_set_attack_conditions(false, false, false)
	_set_tree_bool(param_attack_finished, true)

func update(delta: float, target: Node2D = null, in_scope: bool = false) -> void:
	current_target = target
	current_target_in_scope = in_scope
	if attack_cooldown_left > 0.0:
		attack_cooldown_left = maxf(0.0, attack_cooldown_left - delta)
	if attack_time_left > 0.0:
		attack_time_left = maxf(0.0, attack_time_left - delta)
		var elapsed := attack_duration - attack_time_left
		_process_damage_events(elapsed)
		_on_attack_updated(delta, elapsed)
		if attack_time_left == 0.0:
			_finish_attack()
	else:
		_on_idle_update(delta)

func can_start_attack() -> bool:
	return attack_time_left == 0.0 and attack_cooldown_left == 0.0

func is_busy() -> bool:
	return attack_time_left > 0.0

func is_attacking() -> bool:
	return attack_time_left > 0.0

func is_in_parry_window() -> bool:
	if not is_attacking():
		return false
	var elapsed := attack_duration - attack_time_left
	return elapsed >= parry_window_start and elapsed <= parry_window_end

func can_move() -> bool:
	return current_attack_movable

func force_stop() -> void:
	attack_time_left = 0.0
	attack_duration = 0.0
	current_attack = ""
	current_attack_movable = true
	damage_events.clear()
	_set_attack_conditions(false, false, false)
	_set_tree_bool(param_attack_finished, true)
	_on_force_stop()

func _begin_attack(
		attack_name: String,
		duration: float,
		movable: bool,
		light_attack: bool,
		hard_attack: bool,
		bow_attack: bool
) -> void:
	if not can_start_attack():
		return
	current_attack = attack_name
	attack_duration = maxf(0.0, duration)
	attack_time_left = attack_duration
	current_attack_movable = movable
	damage_events.clear()
	_set_attack_conditions(light_attack, hard_attack, bow_attack)
	_set_tree_bool(param_attack_finished, false)
	
	if audio_service != null and audio_service.has_method("play_sfx_2d") and not bow_attack:
		audio_service.play_sfx_2d("sword_swing", owner.global_position)
		
	_on_attack_started(attack_name)

func _queue_damage_event(
		trigger_time: float,
		damage: float,
		attack_range: float,
		require_facing: bool,
		prefer_context_target: bool
) -> void:
	damage_events.append({
		"trigger_time": maxf(0.0, trigger_time),
		"damage": damage,
		"range": maxf(0.0, attack_range),
		"require_facing": require_facing,
		"prefer_context_target": prefer_context_target,
		"triggered": false
	})

func _on_attack_started(_attack_name: String) -> void:
	pass

func _on_attack_updated(_delta: float, _elapsed: float) -> void:
	pass

func _on_attack_finished(_attack_name: String) -> void:
	pass

func _on_idle_update(_delta: float) -> void:
	pass

func _on_force_stop() -> void:
	pass

func _set_attack_conditions(light_attack: bool, hard_attack: bool, bow_attack: bool) -> void:
	_set_tree_bool(param_is_light_attack, light_attack)
	_set_tree_bool(param_is_hard_attack, hard_attack)
	_set_tree_bool(param_is_bow_attack, bow_attack)
	if param_is_any_attack != "":
		_set_tree_bool(param_is_any_attack, light_attack or hard_attack or bow_attack)
	if param_is_attack_combined != "":
		_set_tree_bool(param_is_attack_combined, light_attack or hard_attack)

func _set_tree_bool(path: String, value: bool) -> void:
	if animation_tree == null or path == "":
		return
	animation_tree.set(path, value)

func _process_damage_events(elapsed: float) -> void:
	for i in range(damage_events.size()):
		var event := damage_events[i]
		if bool(event.get("triggered", false)):
			continue
		if elapsed < float(event.get("trigger_time", 0.0)):
			continue
		event["triggered"] = true
		damage_events[i] = event
		_try_apply_damage_event(event)

func _try_apply_damage_event(event: Dictionary) -> void:
	if _handle_damage_event_override(event):
		return
	var applied := false
	if bool(event.get("prefer_context_target", false)):
		if _is_valid_damage_target(current_target) and current_target_in_scope:
			if _check_clash(current_target):
				_handle_clash(current_target)
			else:
				_apply_damage_to_target(current_target, float(event.get("damage", 0.0)))
			applied = true
	if applied:
		return
	var hit_target: Node2D = _find_attack_target(float(event.get("range", 0.0)), bool(event.get("require_facing", true)))
	if hit_target != null:
		if _check_clash(hit_target):
			_handle_clash(hit_target)
		else:
			_apply_damage_to_target(hit_target, float(event.get("damage", 0.0)))

func _handle_damage_event_override(_event: Dictionary) -> bool:
	return false

func _check_clash(target: Node2D) -> bool:
	if target == null or not target.has_method("get"):
		return false
	var target_attack_module = target.get("attack_module")
	if target_attack_module == null or not target_attack_module.has_method("is_in_parry_window"):
		return false
	
	# Check for posture broken on target
	if target.has_method("is_posture_broken") and target.is_posture_broken():
		return false
	
	# Check if target is facing owner
	var target_sprite = target.get("sprite")
	if target_sprite != null:
		var facing = -1.0 if target_sprite.flip_h else 1.0
		var delta_x = owner.global_position.x - target.global_position.x
		if delta_x * facing <= 0.0:
			return false
			
	return target_attack_module.is_in_parry_window()

func _handle_clash(target: Node2D) -> void:
	# 1. 打断对方的攻击
	var target_attack_module = target.get("attack_module")
	if target_attack_module != null and target_attack_module.has_method("force_stop"):
		target_attack_module.force_stop()
			
	# 2. 增加双方架势条
	if owner != null and owner.has_method("add_posture"):
		owner.add_posture(20.0) # 攻击方增加20
	if target.has_method("add_posture"):
		target.add_posture(40.0) # 防守方(被弹开方)增加40
			
	# 3. 触发免伤受击动画
	if target.has_method("_on_damaged"):
		var health = target.get("health")
		var current_hp = health.current_health if health != null else 100.0
		var max_hp = health.max_health if health != null else 100.0
		target._on_damaged(0.0, current_hp, max_hp, owner)
		
	# 3. 触发拼刀表现 (特效、音效、顿帧)
	_play_clash_effects(target)

func _play_clash_effects(target: Node2D) -> void:
	if owner == null or not owner.is_inside_tree():
		return
		
	var tree = owner.get_tree()
	
	# 顿帧 (Hitstop)
	Engine.time_scale = 0.1
	var timer = tree.create_timer(0.1, true, false, true)
	timer.timeout.connect(func(): Engine.time_scale = 1.0)
	
	# 创建特效节点
	var mid_pos = (owner.global_position + target.global_position) / 2.0
	var effect_node = Node2D.new()
	effect_node.global_position = mid_pos
	
	var current_scene = tree.current_scene
	if current_scene != null:
		current_scene.add_child(effect_node)
	else:
		tree.root.add_child(effect_node)
		
	# 添加火花粒子特效
	var particles = CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = 20
	particles.lifetime = 0.25
	particles.spread = 90.0
	particles.gravity = Vector2(0, 0)
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 120.0
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.2
	particles.color = Color(1.0, 0.8, 0.2)
	effect_node.add_child(particles)
	particles.emitting = true
	
	# 播放打铁音效
	if tree.root.has_node("AudioManager"):
		var audio_manager = tree.root.get_node("AudioManager")
		audio_manager.play_sfx_2d("sword_clash", mid_pos)
	
	# 定时销毁特效节点
	var free_timer = tree.create_timer(1.0, true, false, true)
	free_timer.timeout.connect(func(): if is_instance_valid(effect_node): effect_node.queue_free())

func _find_attack_target(attack_range: float, require_facing: bool) -> Node2D:
	if owner == null or attack_range <= 0.0:
		return null
	var shape := CircleShape2D.new()
	shape.radius = attack_range
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, owner.global_position)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [owner]
	var results := owner.get_world_2d().direct_space_state.intersect_shape(query, 16)
	var best_target: Node2D
	var best_distance := INF
	var facing := -1.0 if sprite != null and sprite.flip_h else 1.0
	for result: Dictionary in results:
		var collider: Object = result.get("collider")
		if not (collider is Node2D):
			continue
		var candidate := collider as Node2D
		if not _is_valid_damage_target(candidate):
			continue
		if require_facing:
			var delta_x := candidate.global_position.x - owner.global_position.x
			if delta_x * facing <= 0.0:
				continue
		var distance := owner.global_position.distance_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best_target = candidate
	return best_target

func _is_valid_damage_target(candidate: Node2D) -> bool:
	if candidate == null:
		return false
	if candidate == owner:
		return false
	if candidate.has_method("is_alive") and not candidate.is_alive():
		return false
	if candidate.has_method("get_team_id") and owner != null and owner.has_method("get_team_id"):
		# Both have teams, only allow if different
		if candidate.get_team_id() == owner.get_team_id():
			return false
	return candidate.has_method("apply_damage")

func _apply_damage_to_target(target: Node2D, damage: float) -> void:
	if not _is_valid_damage_target(target):
		return
	target.call("apply_damage", _get_effective_damage(target, damage), owner)

func _get_effective_damage(target: Node2D, base_damage: float) -> float:
	if owner != null and DeveloperMode.applies_to(owner) and _is_enemy_character_target(target):
		return _get_lethal_damage(target)
	return base_damage

func _is_enemy_character_target(target: Node2D) -> bool:
	if not (target is CharacterBody2D):
		return false
	if owner == null:
		return false
	if not target.has_method("get_team_id") or not owner.has_method("get_team_id"):
		return false
	return int(target.call("get_team_id")) != int(owner.call("get_team_id"))

func _get_lethal_damage(target: Node2D) -> float:
	if target != null and target.has_method("get"):
		var target_health = target.get("health")
		if target_health != null and target_health.get("current_health") != null:
			return maxf(9999.0, float(target_health.current_health) + 1.0)
	return 9999.0

func _get_light_attack_duration(base_duration: float) -> float:
	if owner != null and bool(owner.get("is_player_controlled")):
		return base_duration * PLAYER_LIGHT_ATTACK_DURATION_MULTIPLIER
	return base_duration

func _finish_attack() -> void:
	var ended_attack := current_attack
	current_attack = ""
	attack_time_left = 0.0
	attack_duration = 0.0
	current_attack_movable = true
	damage_events.clear()
	_set_attack_conditions(false, false, false)
	_set_tree_bool(param_attack_finished, true)
	attack_cooldown_left = attack_cooldown
	_on_attack_finished(ended_attack)

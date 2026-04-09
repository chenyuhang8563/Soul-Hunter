class_name AttackModuleBase
extends RefCounted

const PARAM_IS_LIGHT_ATTACK := "parameters/attack_state_machine/conditions/is_light_attack"
const PARAM_IS_HARD_ATTACK := "parameters/attack_state_machine/conditions/is_hard_attack"
const PARAM_IS_BOW_ATTACK := "parameters/attack_state_machine/conditions/is_bow_attack"
const PARAM_IS_ANY_ATTACK := "parameters/conditions/is_any_attack"
const PARAM_ATTACK_FINISHED := "parameters/conditions/attack_finished"
const PARAM_IS_ATTACK_COMBINED := "parameters/conditions/is_light_attack or is_hard_attack"
const PLAYER_LIGHT_ATTACK_DURATION_MULTIPLIER := 0.8
const CRIT_DAMAGE_MULTIPLIER := 1.5
const INCOMING_DAMAGE_IS_CRITICAL_META := "incoming_damage_is_critical"

static var _active_hitstop_requests: Dictionary = {}
static var _next_hitstop_request_id := 1
static var _hitstop_restore_time_scale := 1.0

var owner: CharacterBody2D
var sprite: Sprite2D
var animation_tree: AnimationTree
var stats: CharacterStats
var audio_service: Node = null

var attack_cooldown := 0.30
var base_attack_cooldown := 0.30
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
var _forced_critical_hit_result := -1

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
	base_attack_cooldown = maxf(0.0, cooldown)
	attack_cooldown = base_attack_cooldown
	attack_cooldown_left = 0.0
	attack_time_left = 0.0
	attack_duration = 0.0
	current_attack = ""
	current_attack_movable = true
	damage_events.clear()
	_forced_critical_hit_result = -1
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

func set_attack_cooldown(cooldown: float) -> void:
	attack_cooldown = maxf(0.0, cooldown)
	attack_cooldown_left = minf(attack_cooldown_left, attack_cooldown)

func set_forced_critical_hit(is_critical: bool) -> void:
	_forced_critical_hit_result = 1 if is_critical else 0

func clear_forced_critical_hit() -> void:
	_forced_critical_hit_result = -1

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
		prefer_context_target: bool,
		slash_spec: Dictionary = {}
) -> void:
	damage_events.append({
		"trigger_time": maxf(0.0, trigger_time),
		"damage": damage,
		"range": maxf(0.0, attack_range),
		"require_facing": require_facing,
		"prefer_context_target": prefer_context_target,
		"slash_spec": slash_spec.duplicate(true),
		"triggered": false
	})

func _queue_stat_damage_event(
		trigger_time: float,
		stat_id: StringName,
		fallback_damage: float,
		attack_range: float,
		require_facing: bool,
		prefer_context_target: bool,
		slash_spec: Dictionary = {}
) -> void:
	damage_events.append({
		"trigger_time": maxf(0.0, trigger_time),
		"damage": fallback_damage,
		"stat_id": stat_id,
		"range": maxf(0.0, attack_range),
		"require_facing": require_facing,
		"prefer_context_target": prefer_context_target,
		"slash_spec": slash_spec.duplicate(true),
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

func _create_slash_spec(offset: Vector2, rotation_deg: float, base_scale: Vector2, duration: float, reference_range: float) -> Dictionary:
	return {
		"offset": offset,
		"rotation_deg": rotation_deg,
		"base_scale": base_scale,
		"duration": duration,
		"reference_range": reference_range,
	}

func _get_light_slash_spec() -> Dictionary:
	return _create_slash_spec(Vector2(14.0, -4.0), 28.0, Vector2(1.25, 0.92), 0.10, 42.0)

func _get_hard_slash_spec() -> Dictionary:
	return _create_slash_spec(Vector2(18.0, -6.0), 10.0, Vector2(1.25, 0.92), 0.14, 48.0)

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

func _play_slash_vfx_from_event(event: Dictionary) -> void:
	if owner == null or not is_instance_valid(owner) or not owner.is_inside_tree():
		return
	var manager := _get_slash_vfx_manager()
	if manager == null or not manager.has_method("play_slash"):
		return
	var spec: Dictionary = event.get("slash_spec", {})
	if spec.is_empty():
		return
	manager.call("play_slash", owner, spec, float(event.get("range", 0.0)))

func _get_slash_vfx_manager() -> Node:
	if owner == null or not is_instance_valid(owner) or not owner.is_inside_tree():
		return null
	var tree := owner.get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("MeleeSlashVfxManager")

func _try_apply_damage_event(event: Dictionary) -> void:
	if _handle_damage_event_override(event):
		return
	var hit_targets: Array = []
	if bool(event.get("prefer_context_target", false)):
		if _is_valid_damage_target(current_target) and current_target_in_scope:
			hit_targets.append(current_target)
	for hit_target in _find_attack_targets(float(event.get("range", 0.0)), bool(event.get("require_facing", true))):
		if not hit_targets.has(hit_target):
			hit_targets.append(hit_target)

	var dealt_damage := false
	var damage_result := _resolve_damage_event_result(event)
	var damage_amount := float(damage_result.get("damage", 0.0))
	var critical_hit := bool(damage_result.get("critical_hit", false))
	for hit_target in hit_targets:
		if _check_clash(hit_target):
			_handle_clash(hit_target)
			continue
		if _apply_damage_to_target(hit_target, damage_amount, critical_hit):
			dealt_damage = true
	if dealt_damage:
		_play_slash_vfx_from_event(event)

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
	_apply_hitstop(0.1, 0.1)
	
	var mid_pos = (owner.global_position + target.global_position) / 2.0
	var current_scene = tree.current_scene
	var effect_parent: Node = current_scene if current_scene != null else tree.root
	_spawn_particles_from_template(owner, "ParryParticles", effect_parent, mid_pos)
	
	# 播放打铁音效
	if tree.root.has_node("AudioManager"):
		var audio_manager = tree.root.get_node("AudioManager")
		audio_manager.play_sfx_2d("sword_clash", mid_pos)

func _spawn_particles_from_template(
		source_node: Node,
		particle_name: String,
		effect_parent: Node,
		world_position: Vector2,
		horizontal_direction: float = 0.0
) -> void:
	if effect_parent == null or source_node == null or not is_instance_valid(source_node):
		return
	var particle_template := source_node.find_child(particle_name, true, false)
	if particle_template == null:
		push_warning("%s node not found on %s" % [particle_name, source_node.name])
		return
	var particle_instance := particle_template.duplicate()
	if not (particle_instance is Node2D):
		return
	var particle_node := particle_instance as Node2D
	effect_parent.add_child(particle_node)
	particle_node.global_position = world_position
	_configure_particle_direction_recursive(particle_node, horizontal_direction)
	var cleanup_delay := _restart_particles_recursive(particle_node)
	var tree := source_node.get_tree()
	if tree == null:
		return
	var free_timer = tree.create_timer(cleanup_delay, true, false, true)
	free_timer.timeout.connect(func(): if is_instance_valid(particle_node): particle_node.queue_free())

func _get_finisher_effect_duration() -> float:
	return maxf(
		0.3,
		maxf(
			_get_particle_template_duration(owner, "FinisherBurstParticles"),
			_get_particle_template_duration(owner, "FinisherSlashParticles")
		)
	)

func _get_particle_template_duration(source_node: Node, particle_name: String) -> float:
	if source_node == null or not is_instance_valid(source_node):
		return 0.0
	var particle_template := source_node.find_child(particle_name, true, false)
	if particle_template == null:
		return 0.0
	return _collect_particle_duration_recursive(particle_template)

func _collect_particle_duration_recursive(node: Node) -> float:
	var duration := 0.0
	if node is GPUParticles2D:
		duration = maxf(duration, (node as GPUParticles2D).lifetime)
	elif node is CPUParticles2D:
		duration = maxf(duration, (node as CPUParticles2D).lifetime)
	for child in node.get_children():
		duration = maxf(duration, _collect_particle_duration_recursive(child))
	return duration

func _restart_particles_recursive(node: Node) -> float:
	var cleanup_delay := 1.0
	if node is GPUParticles2D:
		var gpu_particles := node as GPUParticles2D
		gpu_particles.emitting = false
		gpu_particles.restart()
		gpu_particles.emitting = true
		cleanup_delay = maxf(cleanup_delay, gpu_particles.lifetime + 0.2)
	elif node is CPUParticles2D:
		var cpu_particles := node as CPUParticles2D
		cpu_particles.emitting = false
		cpu_particles.restart()
		cpu_particles.emitting = true
		cleanup_delay = maxf(cleanup_delay, cpu_particles.lifetime + 0.2)
	for child in node.get_children():
		cleanup_delay = maxf(cleanup_delay, _restart_particles_recursive(child))
	return cleanup_delay

func _configure_particle_direction_recursive(node: Node, horizontal_direction: float) -> void:
	if node is Node2D:
		_configure_particle_direction(node as Node2D, horizontal_direction)
	for child in node.get_children():
		_configure_particle_direction_recursive(child, horizontal_direction)

func _configure_particle_direction(particle_node: Node2D, horizontal_direction: float) -> void:
	if is_zero_approx(horizontal_direction):
		return
	if particle_node is GPUParticles2D:
		var gpu_particles := particle_node as GPUParticles2D
		var process_material := gpu_particles.process_material
		if process_material is ParticleProcessMaterial:
			var duplicated_material := (process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
			var direction: Vector3 = duplicated_material.direction
			var x_magnitude := absf(direction.x)
			if is_zero_approx(x_magnitude):
				x_magnitude = 1.0
			direction.x = x_magnitude * horizontal_direction
			duplicated_material.direction = direction
			gpu_particles.process_material = duplicated_material
	elif particle_node is CPUParticles2D:
		var cpu_particles := particle_node as CPUParticles2D
		var direction_2d: Vector2 = cpu_particles.direction
		var x_magnitude_2d := absf(direction_2d.x)
		if is_zero_approx(x_magnitude_2d):
			x_magnitude_2d = 1.0
		direction_2d.x = x_magnitude_2d * horizontal_direction
		cpu_particles.direction = direction_2d

func _get_hit_particle_direction(target: Node2D, source: Node2D) -> float:
	if target == null or source == null:
		return 0.0
	var direction := signf(target.global_position.x - source.global_position.x)
	if direction == 0.0:
		direction = 1.0 if randf() > 0.5 else -1.0
	return direction

func _apply_hitstop(duration: float, time_scale: float = 0.0) -> void:
	if owner == null or not owner.is_inside_tree():
		return
	var tree := owner.get_tree()
	if tree == null:
		return
	if _active_hitstop_requests.is_empty():
		_hitstop_restore_time_scale = Engine.time_scale if Engine.time_scale > 0.0 else 1.0
	var request_id := _next_hitstop_request_id
	_next_hitstop_request_id += 1
	_active_hitstop_requests[request_id] = time_scale
	_reapply_hitstop_time_scale()
	var timer := tree.create_timer(duration, true, false, true)
	timer.timeout.connect(func():
		_active_hitstop_requests.erase(request_id)
		_reapply_hitstop_time_scale()
	)

static func _reapply_hitstop_time_scale() -> void:
	if _active_hitstop_requests.is_empty():
		Engine.time_scale = _hitstop_restore_time_scale if _hitstop_restore_time_scale > 0.0 else 1.0
		return
	var active_time_scale := INF
	for pending_time_scale in _active_hitstop_requests.values():
		active_time_scale = minf(active_time_scale, float(pending_time_scale))
	Engine.time_scale = active_time_scale if active_time_scale < INF else 1.0

func _should_trigger_finisher(target: Node2D, damage: float) -> bool:
	if not _is_enemy_character_target(target) or not target.has_method("get"):
		return false
	if target.get("is_player_controlled") == true:
		return false
	var target_health = target.get("health")
	if target_health == null:
		return false
	var current_health_value = target_health.get("current_health")
	if current_health_value == null:
		return false
	return float(current_health_value) > 0.0 and damage >= float(current_health_value)

func _play_finisher_effect(target: Node2D) -> void:
	if owner == null or target == null or not owner.is_inside_tree():
		return
	var tree := owner.get_tree()
	if tree == null:
		return
	var current_scene = tree.current_scene
	var effect_parent: Node = current_scene if current_scene != null else tree.root
	_spawn_particles_from_template(owner, "FinisherBurstParticles", effect_parent, target.global_position)
	_spawn_particles_from_template(owner, "FinisherSlashParticles", effect_parent, target.global_position)
	_apply_hitstop(0.3, 0.0)
	if owner.has_method("lock_possession_input_for_finisher"):
		owner.call("lock_possession_input_for_finisher", _get_finisher_effect_duration())

func _find_attack_targets(attack_range: float, require_facing: bool) -> Array:
	if owner == null or attack_range <= 0.0:
		return []
	var shape := CircleShape2D.new()
	shape.radius = attack_range
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, owner.global_position)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [owner]
	var results := owner.get_world_2d().direct_space_state.intersect_shape(query, 16)
	var targets: Array = []
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
		targets.append(candidate)
	targets.sort_custom(func(left: Node2D, right: Node2D) -> bool:
		return owner.global_position.distance_squared_to(left.global_position) < owner.global_position.distance_squared_to(right.global_position)
	)
	return targets

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

func _apply_damage_to_target(target: Node2D, damage: float, critical_hit: bool = false) -> bool:
	if not _is_valid_damage_target(target):
		return false
	var effective_damage := _get_effective_damage(target, damage)
	var previous_health := _get_target_health_value(target)
	var had_critical_meta := target.has_meta(INCOMING_DAMAGE_IS_CRITICAL_META)
	var previous_critical_meta = null
	if had_critical_meta:
		previous_critical_meta = target.get_meta(INCOMING_DAMAGE_IS_CRITICAL_META)
	target.set_meta(INCOMING_DAMAGE_IS_CRITICAL_META, critical_hit)
	target.call("apply_damage", effective_damage, owner)
	if had_critical_meta:
		target.set_meta(INCOMING_DAMAGE_IS_CRITICAL_META, previous_critical_meta)
	else:
		target.remove_meta(INCOMING_DAMAGE_IS_CRITICAL_META)
	var current_health := _get_target_health_value(target)
	var final_damage := effective_damage
	if not is_nan(previous_health) and not is_nan(current_health):
		final_damage = maxf(0.0, previous_health - current_health)
	if owner != null and owner.has_signal("damage_dealt"):
		owner.emit_signal("damage_dealt", target, final_damage)
	var tree := target.get_tree()
	if tree != null:
		var current_scene = tree.current_scene
		var effect_parent: Node = current_scene if current_scene != null else tree.root
		_spawn_particles_from_template(
			target,
			"HurtParticles",
			effect_parent,
			target.global_position,
			_get_hit_particle_direction(target, owner)
		)
	if final_damage > 0.0 and _is_enemy_character_target(target) and not _is_player_controlled_target(target) and target.has_method("is_alive") and not target.is_alive():
		_play_finisher_effect(target)
	return true

func _get_effective_damage(target: Node2D, base_damage: float) -> float:
	if owner != null and DeveloperMode.applies_to(owner) and _is_enemy_character_target(target):
		return _get_lethal_damage(target)
	return base_damage

func _get_target_health_value(target: Node2D) -> float:
	if target == null or not target.has_method("get"):
		return NAN
	var target_health = target.get("health")
	if target_health == null:
		return NAN
	var current_health_value = target_health.get("current_health")
	if current_health_value == null:
		return NAN
	return float(current_health_value)

func _is_player_controlled_target(target: Node2D) -> bool:
	if target == null or not target.has_method("get"):
		return false
	return target.get("is_player_controlled") == true

func _resolve_damage_event_amount(event: Dictionary) -> float:
	return float(_resolve_damage_event_result(event).get("damage", 0.0))

func _resolve_damage_event_result(event: Dictionary) -> Dictionary:
	var stat_id = event.get("stat_id", &"") as StringName
	var fallback_damage := float(event.get("damage", 0.0))
	var base_damage := fallback_damage
	if stat_id != &"":
		base_damage = _get_stat_value(stat_id, fallback_damage)
	return _apply_critical_damage_result(base_damage)

func _apply_critical_damage(base_damage: float) -> float:
	return float(_apply_critical_damage_result(base_damage).get("damage", 0.0))

func _apply_critical_damage_result(base_damage: float) -> Dictionary:
	if base_damage <= 0.0:
		return {
			"damage": 0.0,
			"critical_hit": false,
		}
	var crit_chance := clampf(_get_stat_value(&"crit_chance", 0.0), 0.0, 100.0)
	var critical_hit := _roll_critical_hit(crit_chance)
	return {
		"damage": base_damage * CRIT_DAMAGE_MULTIPLIER if critical_hit else base_damage,
		"critical_hit": critical_hit,
	}

func _roll_critical_hit(crit_chance: float) -> bool:
	var forced_result := _forced_critical_hit_result
	if forced_result != -1:
		_forced_critical_hit_result = -1
		return forced_result == 1
	if crit_chance <= 0.0:
		return false
	return randf() * 100.0 < crit_chance

func _get_stat_value(stat_id: StringName, fallback: float = 0.0) -> float:
	if owner != null and owner.has_method("get_stat_value"):
		return float(owner.call("get_stat_value", stat_id, fallback))
	return fallback

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

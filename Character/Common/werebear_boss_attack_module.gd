extends "res://Character/Common/attack_module_base.gd"
class_name WerebearBossAttackModule

const ShockWaveScene := preload("res://Character/Werebear/werebear_shock_wave.tscn")

const MOVE_LIGHT := &"light_attack"
const MOVE_HARD := &"hard_attack"
const MOVE_ULTIMATE := &"ultimate_attack"
const MOVE_REACTIVE_BACKSTEP := "reactive_backstep"

const LIGHT_ATTACK_DURATION := 0.90
const HARD_ATTACK_DURATION := 1.30
const ULTIMATE_ATTACK_DURATION := 0.90
const REACTIVE_BACKSTEP_DURATION := 0.34

const LIGHT_ATTACK_HIT_DELAY := 0.20
const HARD_ATTACK_HIT_DELAY := 0.55
const ULTIMATE_IMPACT_TIME := 0.50

const LIGHT_ATTACK_RANGE := 80.0
const HARD_ATTACK_RANGE := 48.0
const SHOCKWAVE_BASE_DAMAGE_RATIO := 1.0
const SHOCKWAVE_EXPAND_HOLD := 0.12
const SHOCKWAVE_INITIAL_SCALE_X := 1.0
const SHOCKWAVE_SCALE_Y := 1.0
const SHOCKWAVE_MASK := 2
const SHOCKWAVE_SPAWN_X_OFFSET := 12.0
const SHOCKWAVE_SPAWN_Y_OFFSET := 6.0

const PHASE_ONE_LIGHT_COOLDOWN := 0.30
const PHASE_ONE_HARD_COOLDOWN := 0.75
const PHASE_ONE_ULTIMATE_COOLDOWN := 1.80
const PHASE_ONE_SHOCKWAVE_TARGET_SCALE_X := 1.0
const PHASE_ONE_SHOCKWAVE_EXPAND_DURATION := 0.0
const PHASE_ONE_SHOCKWAVE_FOLLOW_INTERVAL := 0.05

const PHASE_TWO_LIGHT_COOLDOWN := 0.24
const PHASE_TWO_HARD_COOLDOWN := 0.55
const PHASE_TWO_ULTIMATE_COOLDOWN := 1.10
const PHASE_TWO_SHOCKWAVE_TARGET_SCALE_X := 1.0
const PHASE_TWO_SHOCKWAVE_EXPAND_DURATION := 0.0
const PHASE_TWO_SHOCKWAVE_SEGMENT_SPACING := 28.0
const PHASE_TWO_SHOCKWAVE_SEGMENT_INTERVAL := 0.05
const PHASE_TWO_SHOCKWAVE_SEGMENT_LIFETIME := 0.65
const PHASE_TWO_SCREEN_PADDING := 48.0

const HARD_SEGMENT_COUNT := 2
const HARD_ATTACK_TIMES := [0.0, 0.6, 1.2, 1.3]
const HARD_ATTACK_HIT_DELAYS := [0.22, 0.22]
const HARD_COMBO_CHAIN_WINDOW := 0.26
const CLOSE_RANGE_LIGHT_THRESHOLD := 20.0
const DEFAULT_REACTIVE_BACKSTEP_DISTANCE := 20.0
const DAMAGE_PRESSURE_WINDOW := 0.7
const LIGHT_ATTACK_MOVE_DISTANCE := 28.0
const LIGHT_ATTACK_MOVE_DURATION := 0.22
const HARD_ATTACK_STAGE_ONE_MOVE_DISTANCE := 26.0
const HARD_ATTACK_STAGE_TWO_MOVE_DISTANCE := 42.0
const HARD_ATTACK_MOVE_DURATION := 0.26
const REACTIVE_BACKJUMP_SPEED := 118.0
const REACTIVE_BACKJUMP_VERTICAL_SPEED := 104.0

var _phase_two := false
var _move_cooldowns := {
	MOVE_LIGHT: 0.0,
	MOVE_HARD: 0.0,
	MOVE_ULTIMATE: 0.0,
}
var _ultimate_shockwave_spawned := false
var _current_attack_interrupt_lock := false
var _shockwave_cast_id := 0
var _shockwave_cast_hit_targets: Dictionary = {}
var _phase_two_wave_cast_active := false
var _phase_two_wave_origin := Vector2.ZERO
var _phase_two_wave_spawn_timer := 0.0
var _phase_two_wave_total_spawns := 0
var _phase_two_wave_spawned_count := 0
var _phase_one_follow_wave_pending := false
var _phase_one_follow_wave_timer := 0.0
var hard_combo_step := 0
var hard_combo_chain_left := 0.0
var hard_waiting_next := false
var reactive_backstep_distance := DEFAULT_REACTIVE_BACKSTEP_DISTANCE
var _damage_pressure_time_left := 0.0
var _reactive_backstep_direction := 0.0
var _attack_motion_tween: Tween = null

func setup(
		host: CharacterBody2D,
		sprite_node: Sprite2D = null,
		tree: AnimationTree = null,
		player: AnimationPlayer = null,
		_hitbox: Area2D = null,
		_hitbox_shape: CollisionShape2D = null,
		character_stats: CharacterStats = null,
		setup_attack_speed_multiplier: float = 1.0,
		audio_service_node: Node = null
) -> void:
	super.setup(host, sprite_node, tree, player, _hitbox, _hitbox_shape, character_stats, setup_attack_speed_multiplier, audio_service_node)
	animation_player = player
	if host != null and host.get("reactive_backstep_distance") != null:
		reactive_backstep_distance = maxf(0.0, float(host.get("reactive_backstep_distance")))
	else:
		reactive_backstep_distance = DEFAULT_REACTIVE_BACKSTEP_DISTANCE
	_phase_two = false
	_reset_move_cooldowns()
	_reset_attack_runtime_state()
	_reset_shockwave_cast_state()
	_reset_hard_combo_state(false)
	_damage_pressure_time_left = 0.0

func update(delta: float, target: Node2D = null, in_scope: bool = false) -> void:
	_update_move_cooldowns(delta)
	_damage_pressure_time_left = maxf(0.0, _damage_pressure_time_left - delta)
	super.update(delta, target, in_scope)
	if current_attack == "" and hard_combo_chain_left > 0.0:
		hard_combo_chain_left = maxf(0.0, hard_combo_chain_left - delta)
		if hard_combo_chain_left == 0.0:
			_finish_hard_combo()
	if _can_spawn_ultimate_shockwave():
		_trigger_ultimate_shockwave()
	if _phase_two_wave_cast_active:
		_update_phase_two_wave_cast(delta)
	if _phase_one_follow_wave_pending:
		_update_phase_one_follow_wave(delta)

func try_start_from_input() -> void:
	if InputMap.has_action("ultimate_attack") and Input.is_action_just_pressed("ultimate_attack"):
		request_attack(MOVE_ULTIMATE)
		return
	if InputMap.has_action("hard_attack") and Input.is_action_just_pressed("hard_attack"):
		request_attack(MOVE_HARD)
		return
	if InputMap.has_action("light_attack") and Input.is_action_just_pressed("light_attack"):
		request_attack(MOVE_LIGHT)

func start_ai_attack() -> bool:
	if not can_start_attack():
		return false
	var target_distance := INF
	if current_target != null and owner != null:
		target_distance = owner.global_position.distance_to(current_target.global_position)
	if target_distance <= CLOSE_RANGE_LIGHT_THRESHOLD and can_use_attack(MOVE_LIGHT):
		return request_attack(MOVE_LIGHT)
	if can_use_attack(MOVE_ULTIMATE) and (_phase_two or target_distance >= 26.0) and target_distance >= 18.0:
		return request_attack(MOVE_ULTIMATE)
	if can_use_attack(MOVE_HARD):
		return request_attack(MOVE_HARD)
	return request_attack(MOVE_LIGHT)

func can_start_reactive_backstep(target: Node2D = null) -> bool:
	if owner == null or bool(owner.get("is_player_controlled")):
		return false
	if not can_start_attack():
		return false
	var resolved_target := target
	if resolved_target == null or not is_instance_valid(resolved_target):
		resolved_target = current_target
	if resolved_target == null or not is_instance_valid(resolved_target):
		return false
	var target_distance := owner.global_position.distance_to(resolved_target.global_position)
	return target_distance <= reactive_backstep_distance

func start_reactive_backstep(target: Node2D = null) -> bool:
	if target != null and is_instance_valid(target):
		current_target = target
	if not can_start_reactive_backstep(current_target):
		return false
	_start_reactive_backstep()
	return current_attack == MOVE_REACTIVE_BACKSTEP

func is_reactive_backstepping() -> bool:
	return current_attack == MOVE_REACTIVE_BACKSTEP

func request_attack(move_id: StringName) -> bool:
	if move_id == MOVE_HARD and _can_continue_hard_combo():
		_continue_hard_combo()
		return true
	if move_id != MOVE_HARD and hard_waiting_next:
		_finish_hard_combo()
	if not can_use_attack(move_id):
		return false
	match move_id:
		MOVE_LIGHT:
			_start_light_attack()
		MOVE_HARD:
			_start_hard_combo()
		MOVE_ULTIMATE:
			_start_ultimate_attack()
		_:
			return false
	return true

func can_use_attack(move_id: StringName) -> bool:
	if not can_start_attack():
		return false
	return _get_move_cooldown(move_id) <= 0.0

func enter_phase_two() -> void:
	_phase_two = true

func is_phase_two() -> bool:
	return _phase_two

func blocks_hurt_interrupt() -> bool:
	return _current_attack_interrupt_lock

func _on_attack_finished(ended_attack: String) -> void:
	if ended_attack == String(MOVE_HARD):
		if owner != null and not bool(owner.get("is_player_controlled")):
			if hard_combo_step < HARD_SEGMENT_COUNT:
				attack_cooldown_left = 0.0
				hard_combo_step += 1
				_start_hard_segment(hard_combo_step)
				return
			_finish_hard_combo()
			return
		if hard_combo_step < HARD_SEGMENT_COUNT:
			hard_waiting_next = true
			hard_combo_chain_left = HARD_COMBO_CHAIN_WINDOW
			if animation_player != null and animation_player.has_animation(String(MOVE_HARD)):
				animation_player.seek(HARD_ATTACK_TIMES[hard_combo_step], true)
				animation_player.speed_scale = 0.0
			return
		_finish_hard_combo()
		return
	_set_move_cooldown(StringName(ended_attack), _get_move_cooldown_duration(StringName(ended_attack)))
	_reset_attack_runtime_state()

func _on_force_stop() -> void:
	_stop_attack_motion_tween()
	_reset_attack_runtime_state()
	_reset_shockwave_cast_state()
	_reset_hard_combo_state(true)
	_damage_pressure_time_left = 0.0
	_reactive_backstep_direction = 0.0

func _start_light_attack() -> void:
	_reset_hard_combo_state(true)
	_face_current_target()
	animation_tree.active = true
	_begin_attack(String(MOVE_LIGHT), _get_light_attack_duration(LIGHT_ATTACK_DURATION), true, true, false, false)
	_start_attack_motion_tween(LIGHT_ATTACK_MOVE_DISTANCE, LIGHT_ATTACK_MOVE_DURATION)
	_queue_melee_stat_damage_event(LIGHT_ATTACK_HIT_DELAY, &"light_attack_damage", stats.light_attack_damage, LIGHT_ATTACK_RANGE, true, true, _get_light_slash_spec())

func _start_hard_combo() -> void:
	_reset_hard_combo_state(false)
	hard_combo_step = 1
	_face_current_target()
	_start_hard_segment(hard_combo_step)

func _start_ultimate_attack() -> void:
	_reset_hard_combo_state(true)
	_face_current_target()
	animation_tree.active = true
	_reset_attack_runtime_state()
	_reset_shockwave_cast_state()
	_current_attack_interrupt_lock = true
	_begin_attack(String(MOVE_ULTIMATE), ULTIMATE_ATTACK_DURATION, false, false, false, true)

func _start_hard_segment(combo_step: int) -> void:
	var segment_start := float(HARD_ATTACK_TIMES[combo_step - 1])
	var segment_end := float(HARD_ATTACK_TIMES[combo_step])
	var segment_duration := maxf(0.0, segment_end - segment_start)
	var segment_hit_delay := float(HARD_ATTACK_HIT_DELAYS[combo_step - 1])

	_begin_attack(String(MOVE_HARD), segment_duration, false, false, true, false)
	var move_distance := HARD_ATTACK_STAGE_TWO_MOVE_DISTANCE if combo_step >= 2 else HARD_ATTACK_STAGE_ONE_MOVE_DISTANCE
	_start_attack_motion_tween(move_distance, HARD_ATTACK_MOVE_DURATION)
	_queue_melee_stat_damage_event(segment_hit_delay, &"hard_attack_damage", stats.hard_attack_damage, HARD_ATTACK_RANGE, true, true, _get_hard_slash_spec())
	if animation_player != null and animation_player.has_animation(String(MOVE_HARD)):
		animation_tree.active = false
		animation_player.speed_scale = attack_speed_multiplier
		animation_player.play(String(MOVE_HARD))
		animation_player.seek(segment_start, true)
	else:
		animation_tree.active = true

func _can_spawn_ultimate_shockwave() -> bool:
	if current_attack != String(MOVE_ULTIMATE):
		return false
	if _ultimate_shockwave_spawned or owner == null:
		return false
	var elapsed := attack_duration - attack_time_left
	return elapsed >= ULTIMATE_IMPACT_TIME

func _trigger_ultimate_shockwave() -> void:
	_begin_shockwave_cast()
	if _phase_two:
		_start_phase_two_wave_cast()
	else:
		_spawn_shockwave_segment(Vector2.ZERO, false)
		_start_phase_one_follow_wave()
	_ultimate_shockwave_spawned = true
	_current_attack_interrupt_lock = false

func _begin_shockwave_cast() -> void:
	_shockwave_cast_id += 1
	_shockwave_cast_hit_targets.clear()

func _start_phase_two_wave_cast() -> void:
	if owner == null:
		return
	_phase_two_wave_origin = _get_shockwave_spawn_origin()
	_phase_two_wave_spawn_timer = 0.0
	_phase_two_wave_spawned_count = 0
	_phase_two_wave_total_spawns = _get_phase_two_wave_spawn_count()
	_phase_two_wave_cast_active = _phase_two_wave_total_spawns > 0
	if _phase_two_wave_cast_active:
		_spawn_next_phase_two_wave_segment()

func _update_phase_two_wave_cast(delta: float) -> void:
	if not _phase_two_wave_cast_active:
		return
	if _phase_two_wave_spawned_count >= _phase_two_wave_total_spawns:
		_finish_phase_two_wave_cast()
		return
	_phase_two_wave_spawn_timer -= delta
	while _phase_two_wave_spawn_timer <= 0.0 and _phase_two_wave_spawned_count < _phase_two_wave_total_spawns:
		_spawn_next_phase_two_wave_segment()
		_phase_two_wave_spawn_timer += PHASE_TWO_SHOCKWAVE_SEGMENT_INTERVAL
	if _phase_two_wave_spawned_count >= _phase_two_wave_total_spawns:
		_finish_phase_two_wave_cast()

func _finish_phase_two_wave_cast() -> void:
	_phase_two_wave_cast_active = false
	_phase_two_wave_spawn_timer = 0.0
	_phase_two_wave_total_spawns = 0
	_phase_two_wave_spawned_count = 0

func _start_phase_one_follow_wave() -> void:
	_phase_one_follow_wave_pending = true
	_phase_one_follow_wave_timer = PHASE_ONE_SHOCKWAVE_FOLLOW_INTERVAL

func _update_phase_one_follow_wave(delta: float) -> void:
	if not _phase_one_follow_wave_pending:
		return
	_phase_one_follow_wave_timer -= delta
	if _phase_one_follow_wave_timer > 0.0:
		return
	_phase_one_follow_wave_pending = false
	_phase_one_follow_wave_timer = 0.0
	_spawn_shockwave_segment(Vector2.ZERO, false)

func _spawn_next_phase_two_wave_segment() -> void:
	var segment_index := _phase_two_wave_spawned_count
	_spawn_shockwave_segment(Vector2(_get_phase_two_wave_offset(segment_index), 0.0), true)
	_phase_two_wave_spawned_count += 1

func _get_phase_two_wave_offset(segment_index: int) -> float:
	if segment_index <= 0:
		return 0.0
	var ring_index := int((segment_index + 1) / 2)
	var direction := 1.0 if segment_index % 2 == 1 else -1.0
	return float(ring_index) * PHASE_TWO_SHOCKWAVE_SEGMENT_SPACING * direction

func _get_phase_two_wave_spawn_count() -> int:
	var span := _get_phase_two_wave_span()
	var ring_count := int(ceili(span / PHASE_TWO_SHOCKWAVE_SEGMENT_SPACING))
	return ring_count * 2 + 1

func _get_phase_two_wave_span() -> float:
	var viewport_width := 640.0
	if owner != null and owner.get_viewport() != null:
		viewport_width = maxf(viewport_width, owner.get_viewport_rect().size.x)
	return viewport_width * 0.5 + PHASE_TWO_SCREEN_PADDING

func _spawn_shockwave_segment(offset: Vector2, fullscreen_mode: bool) -> void:
	if owner == null or ShockWaveScene == null:
		return
	var shockwave = ShockWaveScene.instantiate()
	if not (shockwave is Area2D):
		return
	var shockwave_area := shockwave as Area2D
	var spawn_parent := owner.get_parent()
	if spawn_parent == null and owner.get_tree() != null:
		spawn_parent = owner.get_tree().current_scene
	if spawn_parent == null:
		return
	spawn_parent.add_child(shockwave_area)
	var base_position := _get_shockwave_spawn_origin() if not fullscreen_mode else _phase_two_wave_origin
	shockwave_area.global_position = base_position + offset
	if shockwave_area.has_method("setup"):
		shockwave_area.setup({
			"damage_delegate": self,
			"hit_callback": Callable(self, "register_shockwave_hit"),
			"cast_id": _shockwave_cast_id,
			"damage": _get_shockwave_damage(),
			"fullscreen_mode": fullscreen_mode,
			"collision_layer": 0,
			"collision_mask": SHOCKWAVE_MASK,
			"initial_scale_x": SHOCKWAVE_INITIAL_SCALE_X,
			"scale_y": SHOCKWAVE_SCALE_Y,
			"target_scale_x": _get_shockwave_target_scale_x() if not fullscreen_mode else SHOCKWAVE_INITIAL_SCALE_X,
			"expand_duration": _get_shockwave_expand_duration() if not fullscreen_mode else 0.0,
			"hold_duration": PHASE_TWO_SHOCKWAVE_SEGMENT_LIFETIME if fullscreen_mode else SHOCKWAVE_EXPAND_HOLD,
		})

func _get_shockwave_spawn_origin() -> Vector2:
	if owner == null:
		return Vector2.ZERO
	var facing_direction := 1.0
	if sprite != null and sprite.flip_h:
		facing_direction = -1.0
	return owner.global_position + Vector2(SHOCKWAVE_SPAWN_X_OFFSET * facing_direction, SHOCKWAVE_SPAWN_Y_OFFSET)

func _get_shockwave_damage() -> float:
	return _get_stat_value(&"ultimate_attack", stats.ultimate_attack) * SHOCKWAVE_BASE_DAMAGE_RATIO

func _get_shockwave_target_scale_x() -> float:
	if _phase_two:
		return PHASE_TWO_SHOCKWAVE_TARGET_SCALE_X
	return PHASE_ONE_SHOCKWAVE_TARGET_SCALE_X

func _get_shockwave_expand_duration() -> float:
	if _phase_two:
		return PHASE_TWO_SHOCKWAVE_EXPAND_DURATION
	return PHASE_ONE_SHOCKWAVE_EXPAND_DURATION

func register_shockwave_hit(cast_id: int, body: Node2D, damage_amount: float) -> bool:
	if cast_id != _shockwave_cast_id:
		return false
	if owner == null or not is_instance_valid(owner) or not owner.is_inside_tree():
		return false
	if not _is_valid_damage_target(body):
		return false
	var target_id := body.get_instance_id()
	if _shockwave_cast_hit_targets.has(target_id):
		return false
	_shockwave_cast_hit_targets[target_id] = true
	return _apply_damage_to_target(body, damage_amount, false, {})

func notify_damage_taken(amount: float, source: Node2D = null) -> void:
	if amount <= 0.0 or owner == null or bool(owner.get("is_player_controlled")):
		return
	_damage_pressure_time_left = DAMAGE_PRESSURE_WINDOW
	if source != null and is_instance_valid(source) and source is Node2D:
		current_target = source as Node2D

func _on_attack_updated(_delta: float, _elapsed: float) -> void:
	pass

func _sync_attack_animation_speed() -> void:
	if hard_waiting_next and animation_player != null:
		animation_player.speed_scale = 0.0
		return
	super._sync_attack_animation_speed()

func get_attack_motion_velocity(base_velocity: Vector2):
	if current_attack != MOVE_REACTIVE_BACKSTEP:
		return null
	return Vector2(_reactive_backstep_direction * REACTIVE_BACKJUMP_SPEED, base_velocity.y)

func _get_move_cooldown_duration(move_id: StringName) -> float:
	match move_id:
		MOVE_LIGHT:
			return PHASE_TWO_LIGHT_COOLDOWN if _phase_two else PHASE_ONE_LIGHT_COOLDOWN
		MOVE_HARD:
			return PHASE_TWO_HARD_COOLDOWN if _phase_two else PHASE_ONE_HARD_COOLDOWN
		MOVE_ULTIMATE:
			return PHASE_TWO_ULTIMATE_COOLDOWN if _phase_two else PHASE_ONE_ULTIMATE_COOLDOWN
		_:
			return 0.0

func _set_move_cooldown(move_id: StringName, duration: float) -> void:
	if not _move_cooldowns.has(move_id):
		return
	_move_cooldowns[move_id] = maxf(0.0, duration)

func _get_move_cooldown(move_id: StringName) -> float:
	if not _move_cooldowns.has(move_id):
		return 0.0
	return float(_move_cooldowns[move_id])

func _update_move_cooldowns(delta: float) -> void:
	for move_id in _move_cooldowns.keys():
		_move_cooldowns[move_id] = maxf(0.0, float(_move_cooldowns[move_id]) - delta)

func _reset_move_cooldowns() -> void:
	for move_id in _move_cooldowns.keys():
		_move_cooldowns[move_id] = 0.0

func _reset_attack_runtime_state() -> void:
	_stop_attack_motion_tween()
	_ultimate_shockwave_spawned = false
	_current_attack_interrupt_lock = false
	if current_attack != MOVE_REACTIVE_BACKSTEP and owner != null:
		_reactive_backstep_direction = 0.0

func _reset_shockwave_cast_state() -> void:
	_shockwave_cast_hit_targets.clear()
	_phase_one_follow_wave_pending = false
	_phase_one_follow_wave_timer = 0.0
	_phase_two_wave_cast_active = false
	_phase_two_wave_origin = Vector2.ZERO
	_phase_two_wave_spawn_timer = 0.0
	_phase_two_wave_total_spawns = 0
	_phase_two_wave_spawned_count = 0

func _can_continue_hard_combo() -> bool:
	return current_attack == "" and hard_waiting_next and hard_combo_step == 1

func _continue_hard_combo() -> void:
	attack_cooldown_left = 0.0
	hard_combo_step = 2
	hard_waiting_next = false
	hard_combo_chain_left = 0.0
	_face_current_target()
	_start_hard_segment(hard_combo_step)

func _finish_hard_combo() -> void:
	_set_move_cooldown(MOVE_HARD, _get_move_cooldown_duration(MOVE_HARD))
	_reset_hard_combo_state(true)
	_reset_attack_runtime_state()

func _reset_hard_combo_state(stop_animation: bool) -> void:
	hard_combo_step = 0
	hard_combo_chain_left = 0.0
	hard_waiting_next = false
	if animation_player != null:
		animation_player.speed_scale = 1.0
		if stop_animation and animation_player.has_animation(String(MOVE_HARD)):
			animation_player.stop()
	if animation_tree != null:
		animation_tree.active = true

func _face_current_target() -> void:
	if sprite == null or current_target == null or not is_instance_valid(current_target) or owner == null:
		return
	var delta_x := current_target.global_position.x - owner.global_position.x
	if is_zero_approx(delta_x):
		return
	sprite.flip_h = delta_x < 0.0

func _start_attack_motion_tween(distance: float, duration: float) -> void:
	if owner == null or duration <= 0.0 or is_zero_approx(distance):
		return
	var direction := -1.0 if sprite != null and sprite.flip_h else 1.0
	_stop_attack_motion_tween()
	_attack_motion_tween = owner.create_tween()
	_attack_motion_tween.set_trans(Tween.TRANS_QUAD)
	_attack_motion_tween.set_ease(Tween.EASE_OUT)
	_attack_motion_tween.tween_property(owner, "global_position:x", owner.global_position.x + direction * distance, duration)
	_attack_motion_tween.finished.connect(_clear_attack_motion_tween)

func _stop_attack_motion_tween() -> void:
	if _attack_motion_tween != null and is_instance_valid(_attack_motion_tween):
		_attack_motion_tween.kill()
	_attack_motion_tween = null

func _clear_attack_motion_tween() -> void:
	_attack_motion_tween = null

func _start_reactive_backstep() -> void:
	_stop_attack_motion_tween()
	_reset_hard_combo_state(true)
	_face_current_target()
	_damage_pressure_time_left = 0.0
	if owner == null:
		return
	var retreat_direction := 1.0
	if current_target != null and is_instance_valid(current_target):
		var delta_x := current_target.global_position.x - owner.global_position.x
		if not is_zero_approx(delta_x):
			retreat_direction = -signf(delta_x)
	_reactive_backstep_direction = retreat_direction
	owner.velocity.x = retreat_direction * REACTIVE_BACKJUMP_SPEED
	owner.velocity.y = -REACTIVE_BACKJUMP_VERTICAL_SPEED
	_begin_attack(MOVE_REACTIVE_BACKSTEP, REACTIVE_BACKSTEP_DURATION, false, false, false, false)

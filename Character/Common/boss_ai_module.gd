extends "res://Character/Common/ai_module.gd"
class_name BossAIModule

const PHASE_ONE_PREFERRED_DISTANCE := 24.0
const PHASE_ONE_DISTANCE_TOLERANCE := 6.0
const PHASE_TWO_PREFERRED_DISTANCE := 32.0
const PHASE_TWO_DISTANCE_TOLERANCE := 8.0
const PHASE_TWO_MIN_ATTACK_PRESSURE_DISTANCE := 18.0
const PHASE_TWO_WALK_SPEED_MULTIPLIER := 1.15
const DEFAULT_REACTIVE_BACKSTEP_DISTANCE := 20.0
const DEFAULT_REACTIVE_BACKSTEP_CHANCE := 0.2
const INTRO_ROAR_VFX_KEY := &"werebear_roar"
const VFX_POOL_NODE_NAME := "VfxPool"
const AIState_BACKSTEP := 4
const AIState_ROAR := 5

var _phase_two := false
var _base_walk_speed := 50.0
var reactive_backstep_distance := DEFAULT_REACTIVE_BACKSTEP_DISTANCE
var reactive_backstep_chance := DEFAULT_REACTIVE_BACKSTEP_CHANCE
var _backstep_decision_pending := false
var _had_target_last_frame := false
var _was_reactive_backstep_candidate_last_frame := false
var _intro_roar_pending := true
var _intro_roar_playback_serial := 0
var _roar_locked_target: Node2D = null
var _forced_chase_target: Node2D = null

func setup(_character: CharacterBody2D, _sprite: Sprite2D, _visual_scope: Area2D, _attack_scope: Area2D, _line_of_sight: RayCast2D, _attack_module: AttackModuleBase, _walk_speed: float = 50.0, _return_tolerance: float = 6.0) -> void:
	super.setup(_character, _sprite, _visual_scope, _attack_scope, _line_of_sight, _attack_module, _walk_speed, _return_tolerance)
	_phase_two = false
	_base_walk_speed = _walk_speed
	walk_speed = _base_walk_speed
	if _character != null and _character.get("reactive_backstep_distance") != null:
		reactive_backstep_distance = maxf(0.0, float(_character.get("reactive_backstep_distance")))
	else:
		reactive_backstep_distance = DEFAULT_REACTIVE_BACKSTEP_DISTANCE
	if _character != null and _character.get("reactive_backstep_chance") != null:
		reactive_backstep_chance = clampf(float(_character.get("reactive_backstep_chance")), 0.0, 1.0)
	else:
		reactive_backstep_chance = DEFAULT_REACTIVE_BACKSTEP_CHANCE
	_reset_backstep_decision_state()
	_intro_roar_pending = true
	_intro_roar_playback_serial = 0
	_roar_locked_target = null

func enter_phase_two() -> void:
	if _phase_two:
		return
	_phase_two = true
	walk_speed = _base_walk_speed * PHASE_TWO_WALK_SPEED_MULTIPLIER

func is_phase_two() -> bool:
	return _phase_two

func is_in_backstep_state() -> bool:
	return ai_state == AIState_BACKSTEP

func force_stop() -> void:
	_finish_intro_roar(false)
	super.force_stop()
	_reset_backstep_decision_state()
	_forced_chase_target = null

func physics_process_ai(delta: float) -> float:
	if _process_intro_roar():
		return 0.0
	_sync_boss_target_state()
	_sync_backstep_decision_window()
	var target_in_scope := target != null and _is_target_in_attack_scope(target)
	var can_reactive_backstep := target != null and _can_start_reactive_backstep(target)
	var chase_backstep_window := ai_state == AIState.CHASE and can_reactive_backstep and not _was_reactive_backstep_candidate_last_frame
	if attack_module != null and attack_module.has_method("update"):
		attack_module.update(delta, target, target_in_scope)

	if target != null:
		if _is_backstep_attack_active():
			ai_state = AIState_BACKSTEP
		elif ai_state == AIState_BACKSTEP:
			ai_state = AIState.ATTACK if _can_enter_attack_state(target_in_scope) else AIState.CHASE
		elif _should_interrupt_chase_with_backstep(chase_backstep_window):
			ai_state = AIState_BACKSTEP
		elif _should_enter_backstep_state(target):
			ai_state = AIState_BACKSTEP
			_backstep_decision_pending = false
		elif _can_enter_attack_state(target_in_scope):
			ai_state = AIState.ATTACK
			_backstep_decision_pending = false
		elif _is_attack_idle():
			ai_state = AIState.CHASE
			_backstep_decision_pending = false
	elif ai_state != AIState.IDLE:
		ai_state = AIState.RETURN
		_backstep_decision_pending = false

	_was_reactive_backstep_candidate_last_frame = can_reactive_backstep

	var input_dir := 0.0
	if ai_state == AIState.ATTACK:
		if target != null and _can_enter_attack_state(target_in_scope):
			if attack_module.has_method("start_ai_attack"):
				attack_module.start_ai_attack()
		elif _is_attack_idle():
			ai_state = AIState.CHASE
	elif ai_state == AIState_BACKSTEP:
		if not _is_backstep_attack_active():
			if target != null and _can_start_reactive_backstep(target):
				attack_module.call("start_reactive_backstep", target)
			elif target != null:
				ai_state = AIState.ATTACK if _can_enter_attack_state(target_in_scope) else AIState.CHASE
			else:
				ai_state = AIState.IDLE

	if ai_state == AIState.CHASE or ai_state == AIState.RETURN:
		input_dir = _get_move_input()
	elif ai_state == AIState.IDLE or ai_state == AIState_BACKSTEP:
		input_dir = 0.0

	if input_dir != 0.0 and character.is_on_floor():
		_cliff_check_timer += delta
		if _cliff_check_timer >= CLIFF_CHECK_INTERVAL:
			_cliff_check_timer = 0.0
			var current_scene = character.get_tree().current_scene
			var tilemap: TileMapLayer = TileMapUtils.get_tilemap_from_scene(current_scene)
			if tilemap:
				var look_ahead_distance = LOOK_AHEAD_DISTANCE
				var check_depth = CLIFF_CHECK_DEPTH
				var predicted_pos = character.global_position + Vector2(sign(input_dir) * look_ahead_distance, check_depth)
				var map_coord = tilemap.local_to_map(tilemap.to_local(predicted_pos))
				var tile_data = tilemap.get_cell_tile_data(map_coord)
				if tile_data == null:
					input_dir = 0.0
					ai_state = AIState.IDLE

	if input_dir != 0 and sprite != null:
		sprite.flip_h = input_dir < 0

	var can_move = true
	if attack_module != null and attack_module.has_method("can_move"):
		can_move = attack_module.can_move()

	if attack_module != null and attack_module.has_method("get_attack_motion_velocity"):
		var attack_motion_velocity = attack_module.call("get_attack_motion_velocity", character.velocity)
		if attack_motion_velocity is Vector2:
			character.velocity = attack_motion_velocity as Vector2
			return input_dir

	if can_move:
		character.velocity.x = input_dir * walk_speed
	else:
		character.velocity.x = 0.0
		input_dir = 0.0

	return input_dir

func _get_move_input() -> float:
	if ai_state == AIState.RETURN:
		return super._get_move_input()
	if target == null:
		return 0.0

	var target_delta := target.global_position.x - character.global_position.x
	var target_distance := absf(target_delta)
	var preferred_distance := _get_preferred_distance()
	var distance_tolerance := _get_distance_tolerance()
	var target_direction := signf(target_delta)
	var target_in_attack_scope := _is_target_in_attack_scope(target)

	if _phase_two and not target_in_attack_scope and target_distance > PHASE_TWO_MIN_ATTACK_PRESSURE_DISTANCE:
		return target_direction

	if target_distance > preferred_distance + distance_tolerance:
		return target_direction
	if target_distance < preferred_distance - distance_tolerance:
		return 0.0
	return 0.0

func _get_preferred_distance() -> float:
	if _phase_two:
		return PHASE_TWO_PREFERRED_DISTANCE
	return PHASE_ONE_PREFERRED_DISTANCE

func _get_distance_tolerance() -> float:
	if _phase_two:
		return PHASE_TWO_DISTANCE_TOLERANCE
	return PHASE_ONE_DISTANCE_TOLERANCE

func _sync_backstep_decision_window() -> void:
	var has_target := target != null
	if has_target and not _had_target_last_frame:
		_backstep_decision_pending = true
	elif not has_target:
		_backstep_decision_pending = false
	_had_target_last_frame = has_target

func _reset_backstep_decision_state() -> void:
	_backstep_decision_pending = false
	_had_target_last_frame = false
	_was_reactive_backstep_candidate_last_frame = false

func _process_intro_roar() -> bool:
	if not _intro_roar_pending and ai_state != AIState_ROAR:
		return false
	if character == null:
		return false
	if _intro_roar_pending and not character.is_on_floor():
		_hold_intro_idle_pose()
		_release_roar_target_lock()
		return true
	if _intro_roar_pending:
		_start_intro_roar()
	if ai_state != AIState_ROAR:
		return false
	_hold_intro_idle_pose()
	_apply_roar_target_constraints()
	return true

func _start_intro_roar() -> void:
	_intro_roar_pending = false
	_intro_roar_playback_serial += 1
	ai_state = AIState_ROAR
	target = _resolve_intro_roar_target()
	_face_boss_toward_target(target)
	if attack_module != null:
		if attack_module.has_method("force_stop"):
			attack_module.force_stop()
		elif attack_module.has_method("reset"):
			attack_module.reset()
	if not _play_intro_roar_vfx(_intro_roar_playback_serial):
		_finish_intro_roar(true)
		return
	_apply_roar_target_constraints()

func _finish_intro_roar(begin_forced_chase: bool = true) -> void:
	_intro_roar_playback_serial += 1
	var chase_target := _resolve_intro_roar_target() if begin_forced_chase else null
	if chase_target != null:
		_forced_chase_target = chase_target
		target = chase_target
		ai_state = AIState.CHASE
	elif ai_state == AIState_ROAR:
		target = null
		ai_state = AIState.IDLE
	_release_roar_target_lock()

func _hold_intro_idle_pose() -> void:
	ai_state = AIState_ROAR if not _intro_roar_pending else AIState.IDLE
	if character != null:
		character.velocity.x = 0.0
	if sprite != null:
		sprite.frame = 0

func _apply_roar_target_constraints() -> void:
	var resolved_target := target
	if resolved_target == null or not is_instance_valid(resolved_target):
		resolved_target = _roar_locked_target
	if resolved_target == null or not is_instance_valid(resolved_target):
		return
	_lock_roar_target(resolved_target)
	if _roar_locked_target != null and is_instance_valid(_roar_locked_target):
		if _roar_locked_target.has_method("face_towards_world_x"):
			_roar_locked_target.face_towards_world_x(character.global_position.x)
		else:
			_force_node_face_world_x(_roar_locked_target, character.global_position.x)

func _lock_roar_target(target_node: Node2D) -> void:
	if target_node == null or not is_instance_valid(target_node):
		return
	if _roar_locked_target == target_node:
		return
	_release_roar_target_lock()
	_roar_locked_target = target_node
	if _roar_locked_target.has_method("push_external_player_input_lock"):
		_roar_locked_target.push_external_player_input_lock()

func _release_roar_target_lock() -> void:
	if _roar_locked_target == null or not is_instance_valid(_roar_locked_target):
		_roar_locked_target = null
		return
	if _roar_locked_target.has_method("pop_external_player_input_lock"):
		_roar_locked_target.pop_external_player_input_lock()
	_roar_locked_target = null

func _play_intro_roar_vfx(playback_serial: int) -> bool:
	if character == null or character.get_tree() == null:
		return false
	var vfx_pool := character.get_tree().root.get_node_or_null(VFX_POOL_NODE_NAME)
	if vfx_pool == null or not vfx_pool.has_method("play_scene_effect"):
		return false
	var horizontal_direction := -1.0 if sprite != null and sprite.flip_h else 1.0
	var completion_cb := Callable(self, "_on_intro_roar_vfx_finished").bind(playback_serial)
	var effect = vfx_pool.call("play_scene_effect", INTRO_ROAR_VFX_KEY, character.global_position, horizontal_direction, completion_cb)
	return effect != null

func _on_intro_roar_vfx_finished(playback_serial: int) -> void:
	if playback_serial != _intro_roar_playback_serial:
		return
	_finish_intro_roar(true)

func _sync_boss_target_state() -> void:
	if _is_forced_chase_target_valid(_forced_chase_target):
		target = _forced_chase_target
		return
	_forced_chase_target = null
	_sync_target_state()

func _resolve_intro_roar_target() -> Node2D:
	var scene_player := _find_scene_player_target()
	if scene_player != null:
		return scene_player
	if _roar_locked_target != null and _is_forced_chase_target_valid(_roar_locked_target):
		return _roar_locked_target
	if target != null and _is_forced_chase_target_valid(target):
		return target
	return null

func _find_scene_player_target() -> Node2D:
	if character == null or character.get_tree() == null:
		return null
	var best_target: Node2D = null
	var best_distance := INF
	for node in character.get_tree().get_nodes_in_group("player_controlled"):
		if not (node is Node2D):
			continue
		var candidate := node as Node2D
		if not _is_forced_chase_target_valid(candidate):
			continue
		var distance := character.global_position.distance_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best_target = candidate
	return best_target

func _is_forced_chase_target_valid(candidate: Node2D) -> bool:
	if candidate == null or not is_instance_valid(candidate):
		return false
	return is_valid_enemy(candidate)

func _face_boss_toward_target(target_node: Node2D) -> void:
	if sprite == null or character == null or target_node == null or not is_instance_valid(target_node):
		return
	var delta_x := target_node.global_position.x - character.global_position.x
	if is_zero_approx(delta_x):
		return
	sprite.flip_h = delta_x < 0.0

func _force_node_face_world_x(target_node: Node2D, target_world_x: float) -> void:
	if target_node == null or not is_instance_valid(target_node):
		return
	var target_sprite := _find_target_sprite(target_node)
	if target_sprite == null:
		return
	var delta_x := target_world_x - target_node.global_position.x
	if is_zero_approx(delta_x):
		return
	target_sprite.flip_h = delta_x < 0.0

func _find_target_sprite(target_node: Node2D) -> Sprite2D:
	if target_node == null:
		return null
	if target_node.has_method("get"):
		var sprite_prop = target_node.get("sprite")
		if sprite_prop is Sprite2D:
			return sprite_prop as Sprite2D
	var named_sprite := target_node.get_node_or_null("Sprite2D") as Sprite2D
	if named_sprite != null:
		return named_sprite
	for child in target_node.get_children():
		if child is Sprite2D:
			return child as Sprite2D
	return null

func _should_enter_backstep_state(candidate: Node2D) -> bool:
	if not _backstep_decision_pending:
		return false
	if reactive_backstep_chance <= 0.0:
		return false
	if not _can_start_reactive_backstep(candidate):
		return false
	if reactive_backstep_chance >= 1.0:
		return true
	return randf() < reactive_backstep_chance

func _should_interrupt_chase_with_backstep(chase_backstep_window: bool) -> bool:
	if not chase_backstep_window:
		return false
	if reactive_backstep_chance <= 0.0:
		return false
	if reactive_backstep_chance >= 1.0:
		return true
	return randf() < reactive_backstep_chance

func _can_enter_attack_state(target_in_scope: bool) -> bool:
	return target_in_scope and attack_module != null and attack_module.has_method("can_start_attack") and attack_module.can_start_attack()

func _is_attack_idle() -> bool:
	return attack_module != null and attack_module.has_method("is_attacking") and not attack_module.is_attacking()

func _can_start_reactive_backstep(candidate: Node2D) -> bool:
	return attack_module != null and attack_module.has_method("can_start_reactive_backstep") and bool(attack_module.call("can_start_reactive_backstep", candidate))

func _is_backstep_attack_active() -> bool:
	return attack_module != null and attack_module.has_method("is_reactive_backstepping") and bool(attack_module.call("is_reactive_backstepping"))

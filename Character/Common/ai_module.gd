extends RefCounted

enum AIState { IDLE, CHASE, ATTACK, RETURN }

# AI 悬崖检测常量
const LOOK_AHEAD_DISTANCE := 15.0
const CLIFF_CHECK_DEPTH := 20.0

var character: CharacterBody2D
var sprite: Sprite2D
var visual_scope: Area2D
var attack_scope: Area2D
var line_of_sight: RayCast2D
var attack_module: AttackModuleBase = null

var target: Node2D
var home_position := Vector2.ZERO
var ai_state := AIState.IDLE

var walk_speed := 50.0
var return_tolerance := 6.0

# P1-7: 性能优化 - 悬崖检测节流
var _cliff_check_timer := 0.0
const CLIFF_CHECK_INTERVAL := 0.15  # 每0.15秒检查一次悬崖

func setup(_character: CharacterBody2D, _sprite: Sprite2D, _visual_scope: Area2D, _attack_scope: Area2D, _line_of_sight: RayCast2D, _attack_module: AttackModuleBase, _walk_speed: float = 50.0, _return_tolerance: float = 6.0) -> void:
	character = _character
	sprite = _sprite
	visual_scope = _visual_scope
	attack_scope = _attack_scope
	line_of_sight = _line_of_sight
	attack_module = _attack_module
	walk_speed = _walk_speed
	return_tolerance = _return_tolerance

func set_home_position(pos: Vector2) -> void:
	home_position = pos

func move_to(pos: Vector2) -> void:
	home_position = pos
	target = null
	ai_state = AIState.RETURN

func force_stop() -> void:
	if attack_module != null:
		if attack_module.has_method("force_stop"):
			attack_module.force_stop()
		elif attack_module.has_method("reset"):
			attack_module.reset()
	target = null
	ai_state = AIState.IDLE

func interrupt_attack() -> void:
	if attack_module != null:
		if attack_module.has_method("force_stop"):
			attack_module.force_stop()
		elif attack_module.has_method("reset"):
			attack_module.reset()
	if target != null:
		ai_state = AIState.CHASE
	else:
		ai_state = AIState.IDLE

func _find_best_target() -> Node2D:
	var best_target: Node2D
	var best_distance := INF
	if visual_scope == null or not visual_scope.monitoring:
		return null
	for body in visual_scope.get_overlapping_bodies():
		if body == character:
			continue
		if body is Node2D:
			var candidate := body as Node2D
			if not is_valid_enemy(candidate):
				continue
			if not _has_line_of_sight(candidate):
				continue
			var distance := character.global_position.distance_to(candidate.global_position)
			if distance < best_distance:
				best_distance = distance
				best_target = candidate
	return best_target

func _has_line_of_sight(candidate: Node2D) -> bool:
	if line_of_sight == null:
		return true
	line_of_sight.target_position = character.to_local(candidate.global_position)
	line_of_sight.force_raycast_update()
	if not line_of_sight.is_colliding():
		return true
	return line_of_sight.get_collider() == candidate

func _is_target_in_attack_scope(candidate: Node2D) -> bool:
	if attack_scope == null:
		return false
	for body in attack_scope.get_overlapping_bodies():
		if body == candidate:
			return true
	return false

func _sync_target_state() -> void:
	if is_instance_valid(target):
		if not is_valid_enemy(target) or not _has_line_of_sight(target):
			target = null
	else:
		target = null
	if target == null:
		target = _find_best_target()

func is_valid_enemy(candidate: Node2D) -> bool:
	if candidate == character:
		return false
	if candidate.has_method("is_alive") and not candidate.is_alive():
		return false
	if candidate.has_method("get_team_id") and character.has_method("get_team_id"):
		if candidate.get_team_id() == character.get_team_id():
			return false
	return candidate.has_method("apply_damage")

func find_player_attack_target() -> Node2D:
	if attack_scope == null:
		return null
	var best_target: Node2D
	var best_distance := INF
	for body in attack_scope.get_overlapping_bodies():
		if body == character:
			continue
		if body is Node2D:
			var candidate := body as Node2D
			if not is_valid_enemy(candidate):
				continue
			var distance := character.global_position.distance_to(candidate.global_position)
			if distance < best_distance:
				best_distance = distance
				best_target = candidate
	return best_target

func _get_move_input() -> float:
	if ai_state == AIState.RETURN:
		var home_delta := home_position.x - character.global_position.x
		if absf(home_delta) <= return_tolerance:
			ai_state = AIState.IDLE
			return 0.0
		return signf(home_delta)
	if target == null:
		return 0.0
	var target_delta := target.global_position.x - character.global_position.x
	if absf(target_delta) <= return_tolerance:
		return 0.0
	return signf(target_delta)

func physics_process_ai(delta: float) -> float:
	_sync_target_state()
	var target_in_scope := target != null and _is_target_in_attack_scope(target)
	if attack_module != null and attack_module.has_method("update"):
		attack_module.update(delta, target, target_in_scope)

	if target != null:
		if target_in_scope and attack_module != null and attack_module.has_method("can_start_attack") and attack_module.can_start_attack():
			ai_state = AIState.ATTACK
		elif attack_module != null and attack_module.has_method("is_attacking") and not attack_module.is_attacking():
			ai_state = AIState.CHASE
	elif ai_state != AIState.IDLE:
		ai_state = AIState.RETURN

	var input_dir := 0.0
	if ai_state == AIState.ATTACK:
		if target != null and target_in_scope and attack_module != null and attack_module.has_method("can_start_attack") and attack_module.can_start_attack():
			if attack_module.has_method("start_ai_attack"):
				attack_module.start_ai_attack()
		elif attack_module != null and attack_module.has_method("is_attacking") and not attack_module.is_attacking():
			ai_state = AIState.CHASE
			
	if ai_state == AIState.CHASE or ai_state == AIState.RETURN:
		input_dir = _get_move_input()
	elif ai_state == AIState.IDLE:
		input_dir = 0.0

	# P1-7: 边缘检测逻辑 - 节流优化，每0.15秒检查一次
	if input_dir != 0.0 and character.is_on_floor():
		_cliff_check_timer += delta
		if _cliff_check_timer >= CLIFF_CHECK_INTERVAL:
			_cliff_check_timer = 0.0
			var current_scene = character.get_tree().current_scene
			var tilemap: TileMapLayer = TileMapUtils.get_tilemap_from_scene(current_scene)
			if tilemap:
				# 预测角色前方一小段距离的脚下坐标
				var look_ahead_distance = LOOK_AHEAD_DISTANCE
				var check_depth = CLIFF_CHECK_DEPTH
				var predicted_pos = character.global_position + Vector2(sign(input_dir) * look_ahead_distance, check_depth)
				var map_coord = tilemap.local_to_map(tilemap.to_local(predicted_pos))
				var tile_data = tilemap.get_cell_tile_data(map_coord)
				# 如果前方脚下没有瓦片（悬崖），强制停止移动
				if tile_data == null:
					input_dir = 0.0
					ai_state = AIState.IDLE # 重置为待机状态，防止不断抽搐

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

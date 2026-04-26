extends Node
class_name ArenaRunController

signal wave_started(wave_index)
signal wave_cleared(wave_index)
signal reward_options_ready(cards)
signal rest_started(seconds)
signal run_completed()
signal run_failed(reached_wave)

const RunModifierControllerScript := preload("res://Character/Common/run_modifier_controller.gd")
const ARENA_ENEMY_GROUP := &"arena_enemy"
const ARENA_WAVE_META_KEY := &"arena_wave_index"
const WAVE_CLEAR_REWARD_BUFFER_SECONDS := 1.5
const HEALTH_POTION_ID := 1
const HEALTH_POTION_DROP_CHANCE := 0.5
const HEALTH_POTION_HEAL_AMOUNT := 80
const PICKUP_ITEM_SCENE := preload("res://Scenes/Items/pickup_item.tscn")

enum RunState {
	PREPARE,
	IN_WAVE,
	REWARD_SELECTION,
	REST,
	VICTORY,
	DEFEAT,
}

@export var rest_duration := 3.0

var current_state: RunState = RunState.PREPARE
var current_wave := 0
var current_wave_plan: Dictionary = {}

var _player: Node = null
var _reward_pool: Resource = null
var _wave_director: RefCounted = null
var _run_modifier_controller: RunModifierController = null
var _reward_options: Array = []
var _rest_time_left := 0.0
var _rng := RandomNumberGenerator.new()
var _enemy_container: Node = null
var _spawn_points: Array = []
var _active_enemies: Array = []
var _reserved_spawn_positions: Array = []
var _wave_clear_buffer_pending := false
var _wave_clear_buffer_token := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_prop_manager_signals()

func _process(delta: float) -> void:
	_sync_current_player_reference()
	if current_state == RunState.IN_WAVE:
		_prune_non_hostile_enemies()
	if current_state == RunState.REST:
		advance_rest_time(delta)

func setup(player: Node, reward_pool: Resource, wave_director: RefCounted, run_modifier_controller: RunModifierController = null) -> void:
	_reset_wave_clear_buffer()
	_disconnect_player_health()
	_player = player
	_reward_pool = reward_pool
	_wave_director = wave_director
	_run_modifier_controller = run_modifier_controller
	if _run_modifier_controller == null:
		_run_modifier_controller = RunModifierControllerScript.new()
	if _player != null:
		_run_modifier_controller.setup(_player)
	_rng.randomize()
	current_state = RunState.PREPARE
	current_wave = 0
	current_wave_plan.clear()
	_reward_options.clear()
	_rest_time_left = 0.0
	_active_enemies.clear()
	_reserved_spawn_positions.clear()
	_set_tree_paused(false)
	_connect_player_health()

func configure_runtime(enemy_container: Node, spawn_points: Array) -> void:
	_enemy_container = enemy_container
	_spawn_points = []
	for spawn_point in spawn_points:
		if spawn_point is Node2D:
			_spawn_points.append(spawn_point)

func start_run() -> void:
	if _wave_director == null:
		return
	current_wave = 1
	_start_wave(current_wave)

func complete_current_wave() -> void:
	if current_state != RunState.IN_WAVE:
		return

	_reset_wave_clear_buffer()
	wave_cleared.emit(current_wave)
	if current_wave >= _get_total_waves():
		current_state = RunState.VICTORY
		_set_tree_paused(false)
		run_completed.emit()
		return

	_reward_options = _roll_reward_options()
	current_state = RunState.REWARD_SELECTION
	_set_tree_paused(true)
	reward_options_ready.emit(_reward_options.duplicate())

func select_reward_card(card_id: StringName) -> bool:
	if current_state != RunState.REWARD_SELECTION:
		return false

	for card in _reward_options:
		if card != null and card.id == card_id:
			_run_modifier_controller.apply_reward_card(card)
			_reward_options.clear()
			_rest_time_left = rest_duration
			current_state = RunState.REST
			_set_tree_paused(false)
			rest_started.emit(_rest_time_left)
			return true

	return false

func advance_rest_time(delta: float) -> void:
	if current_state != RunState.REST:
		return

	_rest_time_left = maxf(0.0, _rest_time_left - delta)
	if _rest_time_left > 0.0:
		return

	current_wave += 1
	_start_wave(current_wave)

func fail_run() -> void:
	if current_state == RunState.VICTORY or current_state == RunState.DEFEAT:
		return
	_reset_wave_clear_buffer()
	current_state = RunState.DEFEAT
	_set_tree_paused(true)
	run_failed.emit(current_wave)

func get_reward_options() -> Array:
	return _reward_options.duplicate()

func get_run_modifier_controller() -> RunModifierController:
	return _run_modifier_controller

func get_total_waves() -> int:
	return _get_total_waves()

func get_rest_time_left() -> float:
	return _rest_time_left

func jump_to_rest_after_wave(wave_index: int) -> bool:
	var total_waves := _get_total_waves()
	if total_waves <= 1:
		return false
	var target_wave := clampi(wave_index, 1, total_waves - 1)
	_reset_wave_clear_buffer()
	_clear_spawned_wave_enemies()
	_active_enemies.clear()
	_reward_options.clear()
	current_wave = target_wave
	current_wave_plan.clear()
	_rest_time_left = rest_duration
	current_state = RunState.REST
	_set_tree_paused(false)
	rest_started.emit(_rest_time_left)
	return true

func _start_wave(wave_index: int) -> void:
	_reset_wave_clear_buffer()
	current_state = RunState.IN_WAVE
	current_wave_plan = _wave_director.build_wave_plan(wave_index, _rng)
	_spawn_current_wave()
	wave_started.emit(wave_index)

func _roll_reward_options() -> Array:
	if _reward_pool == null or not _reward_pool.has_method("roll_cards"):
		return []
	var excluded_skill_card_ids: Array = []
	if _run_modifier_controller != null and _run_modifier_controller.has_method("get_selected_skill_cards"):
		excluded_skill_card_ids = _run_modifier_controller.get_selected_skill_cards()
	return _reward_pool.roll_cards(3, _rng, excluded_skill_card_ids)

func _get_total_waves() -> int:
	if _wave_director != null and _wave_director.has_method("get_total_waves"):
		return int(_wave_director.get_total_waves())
	return 0

func _set_tree_paused(should_pause: bool) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree != null:
		tree.paused = should_pause

func _sync_current_player_reference() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	var current_player: Node = null
	for node in tree.get_nodes_in_group(&"player_controlled"):
		current_player = node
		break
	if current_player == _player:
		return
	_disconnect_player_health()
	_player = current_player
	if _run_modifier_controller != null and _player != null:
		_run_modifier_controller.setup(_player)
	_connect_player_health()

func _spawn_current_wave() -> void:
	_active_enemies.clear()
	_reserved_spawn_positions.clear()
	if _enemy_container == null or _spawn_points.is_empty():
		return

	var spawn_entries: Array = current_wave_plan.get("spawns", [])
	var health_multiplier := float(current_wave_plan.get("health_multiplier", 1.0))
	var attack_multiplier := float(current_wave_plan.get("attack_multiplier", 1.0))
	var move_speed_multiplier := float(current_wave_plan.get("move_speed_multiplier", 1.0))

	for spawn_entry in spawn_entries:
		var enemy_entry = spawn_entry.get("entry")
		if enemy_entry == null or enemy_entry.enemy_scene == null:
			continue
		var enemy_count := int(spawn_entry.get("enemy_count", 0))
		for enemy_index in range(enemy_count):
			var enemy = enemy_entry.enemy_scene.instantiate()
			if not (enemy is Node2D):
				continue
			var spawn_point: Node2D = _spawn_points[_rng.randi_range(0, _spawn_points.size() - 1)]
			var spawn_position := _resolve_spawn_position(spawn_point.global_position, enemy)
			var local_spawn_position: Vector2 = _enemy_container.to_local(spawn_position)
			(enemy as Node2D).position = local_spawn_position
			_prepare_enemy_instance(enemy, health_multiplier, attack_multiplier, move_speed_multiplier)
			_enemy_container.add_child(enemy)
			(enemy as Node2D).global_position = spawn_position
			_reserved_spawn_positions.append(spawn_position)
			_sync_spawn_metadata(enemy, spawn_position)
			_track_enemy(enemy)

func _resolve_spawn_position(spawn_origin: Vector2, enemy: Node2D) -> Vector2:
	var spacing := _estimate_spawn_spacing(enemy)
	if _is_spawn_position_clear(spawn_origin, spacing):
		return spawn_origin

	var directions := [
		Vector2.RIGHT,
		Vector2.LEFT,
		Vector2.UP,
		Vector2.DOWN,
		Vector2(1.0, 1.0).normalized(),
		Vector2(-1.0, 1.0).normalized(),
		Vector2(1.0, -1.0).normalized(),
		Vector2(-1.0, -1.0).normalized(),
	]
	for ring in range(1, 5):
		var radius := spacing * float(ring)
		for direction in directions:
			var candidate: Vector2 = spawn_origin + direction * radius
			if _is_spawn_position_clear(candidate, spacing):
				return candidate
	return spawn_origin

func _estimate_spawn_spacing(enemy: Node2D) -> float:
	var collision_shape := enemy.find_child("CollisionShape2D", true, false) as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return 24.0
	var shape := collision_shape.shape
	if shape is RectangleShape2D:
		var size := (shape as RectangleShape2D).size
		return maxf(size.x, size.y) + 6.0
	if shape is CircleShape2D:
		return (shape as CircleShape2D).radius * 2.0 + 6.0
	if shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		return maxf(capsule.radius * 2.0, capsule.height) + 6.0
	return 24.0

func _is_spawn_position_clear(candidate: Vector2, spacing: float) -> bool:
	for reserved_position in _reserved_spawn_positions:
		var reserved_position_vector: Vector2 = reserved_position
		if reserved_position_vector.distance_to(candidate) < spacing:
			return false
	if _player != null and _player is Node2D:
		var player_node := _player as Node2D
		if player_node.global_position.distance_to(candidate) < spacing:
			return false
	return true

func _prepare_enemy_instance(enemy: Node, health_multiplier: float, attack_multiplier: float, move_speed_multiplier: float) -> void:
	if enemy.has_method("set"):
		if enemy.get("team_id") != null:
			enemy.set("team_id", 1)
		if enemy.get("auto_revive") != null:
			enemy.set("auto_revive", false)
		if enemy.get("start_player_controlled") != null:
			enemy.set("start_player_controlled", false)
		if enemy.get("stats") != null:
			var runtime_stats = enemy.get("stats").duplicate()
			if runtime_stats.get("max_health") != null:
				runtime_stats.max_health *= health_multiplier
			if runtime_stats.get("light_attack_damage") != null:
				runtime_stats.light_attack_damage *= attack_multiplier
			if runtime_stats.get("hard_attack_damage") != null:
				runtime_stats.hard_attack_damage *= attack_multiplier
			if runtime_stats.get("ultimate_attack") != null:
				runtime_stats.ultimate_attack *= attack_multiplier
			if runtime_stats.get("move_speed") != null:
				runtime_stats.move_speed *= move_speed_multiplier
			enemy.set("stats", runtime_stats)

func _track_enemy(enemy: Node) -> void:
	_active_enemies.append(enemy)
	enemy.add_to_group(ARENA_ENEMY_GROUP)
	enemy.set_meta(ARENA_WAVE_META_KEY, current_wave)
	if enemy.has_signal("tree_exited"):
		var tree_exit_callable := Callable(self, "_on_enemy_tree_exited").bind(enemy)
		if not enemy.tree_exited.is_connected(tree_exit_callable):
			enemy.tree_exited.connect(tree_exit_callable, CONNECT_ONE_SHOT)
	if enemy.has_method("get"):
		var health_component = enemy.get("health")
		if health_component != null and health_component.has_signal("died"):
			var death_callable := Callable(self, "_on_enemy_died").bind(enemy)
			if not health_component.died.is_connected(death_callable):
				health_component.died.connect(death_callable, CONNECT_ONE_SHOT)

func _on_enemy_died(_source: CharacterBody2D, enemy: Node) -> void:
	if _rng.randf() < HEALTH_POTION_DROP_CHANCE:
		_spawn_pickup(enemy.global_position, HEALTH_POTION_ID, 1)
	_remove_active_enemy(enemy)

func _spawn_pickup(position: Vector2, item_id: int, count: int) -> void:
	var pickup = PICKUP_ITEM_SCENE.instantiate()
	pickup.setup(item_id, count)
	call_deferred("_add_spawned_pickup", pickup, position)

func _add_spawned_pickup(pickup: Node2D, position: Vector2) -> void:
	if not is_instance_valid(pickup):
		return
	if is_instance_valid(_enemy_container):
		_enemy_container.add_child(pickup)
	else:
		pickup.queue_free()
		return
	pickup.jump_out(position)

func _on_enemy_tree_exited(enemy: Node) -> void:
	_remove_active_enemy(enemy)

func _remove_active_enemy(enemy: Node) -> void:
	var previous_enemy_count := _active_enemies.size()
	_active_enemies.erase(enemy)
	if _active_enemies.size() == previous_enemy_count:
		return
	if not is_inside_tree():
		return
	if current_state == RunState.IN_WAVE and _active_enemies.is_empty():
		_complete_current_wave_if_no_hostiles_remain()

func _prune_non_hostile_enemies() -> void:
	if _active_enemies.is_empty():
		_complete_current_wave_if_no_hostiles_remain()
		return

	var filtered_enemies: Array = []
	for enemy in _active_enemies:
		if _is_hostile_wave_enemy(enemy):
			filtered_enemies.append(enemy)
	_active_enemies = filtered_enemies

	if _active_enemies.is_empty():
		_complete_current_wave_if_no_hostiles_remain()

func _is_hostile_wave_enemy(enemy: Node) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if enemy.has_meta(ARENA_WAVE_META_KEY):
		if int(enemy.get_meta(ARENA_WAVE_META_KEY, -1)) != current_wave:
			return false
	if enemy.has_method("is_alive") and not bool(enemy.call("is_alive")):
		return false
	if enemy.has_method("get_team_id") and _player != null and _player.has_method("get_team_id"):
		if int(enemy.call("get_team_id")) == int(_player.call("get_team_id")):
			return false
	if enemy.get("is_player_controlled") != null and bool(enemy.get("is_player_controlled")):
		return false
	return true

func _complete_current_wave_if_no_hostiles_remain() -> void:
	if current_state != RunState.IN_WAVE:
		return
	_rebuild_active_enemy_snapshot()
	if _active_enemies.is_empty() and not _has_living_wave_enemies():
		_begin_wave_clear_buffer()

func _begin_wave_clear_buffer() -> void:
	if _wave_clear_buffer_pending or not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	_wave_clear_buffer_pending = true
	var scheduled_wave := current_wave
	var scheduled_token := _wave_clear_buffer_token
	var timer := tree.create_timer(WAVE_CLEAR_REWARD_BUFFER_SECONDS, true, false, true)
	timer.timeout.connect(func() -> void:
		if scheduled_token != _wave_clear_buffer_token:
			return
		_wave_clear_buffer_pending = false
		if current_state != RunState.IN_WAVE or current_wave != scheduled_wave:
			return
		_rebuild_active_enemy_snapshot()
		if _active_enemies.is_empty() and not _has_living_wave_enemies():
			complete_current_wave()
	)

func _reset_wave_clear_buffer() -> void:
	_wave_clear_buffer_pending = false
	_wave_clear_buffer_token += 1

func _rebuild_active_enemy_snapshot() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	var rebuilt_enemies: Array = []
	for enemy in tree.get_nodes_in_group(ARENA_ENEMY_GROUP):
		if _is_hostile_wave_enemy(enemy):
			rebuilt_enemies.append(enemy)
	_active_enemies = rebuilt_enemies

func _clear_spawned_wave_enemies() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	for enemy in tree.get_nodes_in_group(ARENA_ENEMY_GROUP):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy == _player:
			continue
		if enemy.is_in_group(&"player_controlled"):
			continue
		if enemy.get("is_player_controlled") != null and bool(enemy.get("is_player_controlled")):
			continue
		enemy.queue_free()

func _has_living_wave_enemies() -> bool:
	if not is_inside_tree():
		return false
	var tree := get_tree()
	if tree == null:
		return false
	for enemy in tree.get_nodes_in_group(ARENA_ENEMY_GROUP):
		if _is_living_wave_enemy(enemy):
			return true
	return false

func _is_living_wave_enemy(enemy: Node) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if not enemy.has_meta(ARENA_WAVE_META_KEY):
		return false
	if int(enemy.get_meta(ARENA_WAVE_META_KEY, -1)) != current_wave:
		return false
	if enemy.get("is_player_controlled") != null and bool(enemy.get("is_player_controlled")):
		return false
	if enemy.has_method("is_alive"):
		return bool(enemy.call("is_alive"))
	if enemy.get("is_dead") != null:
		return not bool(enemy.get("is_dead"))
	return true

func _sync_spawn_metadata(enemy: Node, spawn_position: Vector2) -> void:
	if enemy.get("spawn_position") != null:
		enemy.set("spawn_position", spawn_position)
	if enemy.get("ai_module") != null and enemy.ai_module != null and enemy.ai_module.has_method("set_home_position"):
		enemy.ai_module.set_home_position(spawn_position)

func _connect_player_health() -> void:
	if _player == null or not _player.has_method("get"):
		return
	var health_component = _player.get("health")
	if health_component != null and health_component.has_signal("died"):
		var death_callable := Callable(self, "_on_player_died")
		if not health_component.died.is_connected(death_callable):
			health_component.died.connect(death_callable)

func _disconnect_player_health() -> void:
	if _player == null or not _player.has_method("get"):
		return
	var health_component = _player.get("health")
	if health_component != null and health_component.has_signal("died"):
		var death_callable := Callable(self, "_on_player_died")
		if health_component.died.is_connected(death_callable):
			health_component.died.disconnect(death_callable)

func _on_player_died(_source: CharacterBody2D) -> void:
	fail_run()

func _connect_prop_manager_signals() -> void:
	if not PropManager.prop_used.is_connected(_on_prop_used):
		PropManager.prop_used.connect(_on_prop_used)

func _on_prop_used(item_id: int) -> void:
	if item_id != HEALTH_POTION_ID:
		return
	if _player == null or not _player.has_method("heal"):
		return
	_player.heal(HEALTH_POTION_HEAL_AMOUNT)

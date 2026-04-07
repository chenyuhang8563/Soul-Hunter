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

enum RunState {
	PREPARE,
	IN_WAVE,
	REWARD_SELECTION,
	REST,
	VICTORY,
	DEFEAT,
}

@export var rest_duration := 5.0

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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if current_state == RunState.IN_WAVE:
		_prune_non_hostile_enemies()
	if current_state == RunState.REST:
		advance_rest_time(delta)

func setup(player: Node, reward_pool: Resource, wave_director: RefCounted, run_modifier_controller: RunModifierController = null) -> void:
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
	current_state = RunState.DEFEAT
	_set_tree_paused(false)
	run_failed.emit(current_wave)

func get_reward_options() -> Array:
	return _reward_options.duplicate()

func get_run_modifier_controller() -> RunModifierController:
	return _run_modifier_controller

func get_rest_time_left() -> float:
	return _rest_time_left

func _start_wave(wave_index: int) -> void:
	current_state = RunState.IN_WAVE
	current_wave_plan = _wave_director.build_wave_plan(wave_index, _rng)
	_spawn_current_wave()
	wave_started.emit(wave_index)

func _roll_reward_options() -> Array:
	if _reward_pool == null or not _reward_pool.has_method("roll_cards"):
		return []
	return _reward_pool.roll_cards(3, _rng)

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

func _spawn_current_wave() -> void:
	_active_enemies.clear()
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
			var local_spawn_position: Vector2 = _enemy_container.to_local(spawn_point.global_position)
			(enemy as Node2D).position = local_spawn_position
			_prepare_enemy_instance(enemy, health_multiplier, attack_multiplier, move_speed_multiplier)
			_enemy_container.add_child(enemy)
			(enemy as Node2D).global_position = spawn_point.global_position
			_sync_spawn_metadata(enemy, spawn_point.global_position)
			_track_enemy(enemy)

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
	_remove_active_enemy(enemy)

func _on_enemy_tree_exited(enemy: Node) -> void:
	_remove_active_enemy(enemy)

func _remove_active_enemy(enemy: Node) -> void:
	_active_enemies.erase(enemy)
	if not is_inside_tree():
		return
	if current_state == RunState.IN_WAVE and _active_enemies.is_empty():
		complete_current_wave()

func _prune_non_hostile_enemies() -> void:
	if _active_enemies.is_empty():
		return

	var filtered_enemies: Array = []
	for enemy in _active_enemies:
		if _is_hostile_wave_enemy(enemy):
			filtered_enemies.append(enemy)
	_active_enemies = filtered_enemies

	if _active_enemies.is_empty():
		complete_current_wave()

func _is_hostile_wave_enemy(enemy: Node) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if enemy.has_method("is_alive") and not bool(enemy.call("is_alive")):
		return false
	if enemy.has_method("get_team_id") and _player != null and _player.has_method("get_team_id"):
		if int(enemy.call("get_team_id")) == int(_player.call("get_team_id")):
			return false
	if enemy.get("is_player_controlled") != null and bool(enemy.get("is_player_controlled")):
		return false
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

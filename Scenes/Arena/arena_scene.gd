extends Node2D

const ArenaRunControllerScript := preload("res://Scenes/Arena/arena_run_controller.gd")
const ArenaHudScript := preload("res://Scenes/Arena/arena_hud.gd")
const RewardSelectionUIScript := preload("res://Scenes/Arena/reward_selection_ui.gd")
const RunResultUIScript := preload("res://Scenes/Arena/run_result_ui.gd")
const PauseUIScene := preload("res://Scenes/UI/pause_ui.tscn")
const WaveDirectorScript := preload("res://Global/Roguelike/wave_director.gd")
const RewardPoolResource := preload("res://Data/Roguelike/reward_pool_basic.tres")
const WaveDirectorConfigResource := preload("res://Data/Roguelike/wave_director_basic.tres")
const FALLBACK_EXIT_SCENE := "res://Scenes/level_1.tscn"

@onready var player = $Soldier

var _arena_controller: ArenaRunController = null
var _hud: ArenaHud = null
var _reward_ui: RewardSelectionUI = null
var _result_ui: RunResultUI = null
var _pause_ui: CanvasLayer = null
var _scene_manager_override: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_runtime()
	_setup_ui()
	_connect_signals()
	_arena_controller.start_run()

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if _pause_ui != null and _pause_ui.visible:
		if _pause_ui.handle_pause_action():
			get_viewport().set_input_as_handled()
		return
	if _toggle_pause_menu():
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if _arena_controller == null or _hud == null:
		return
	if _arena_controller.current_state == ArenaRunController.RunState.REST:
		_hud.set_rest_time(_arena_controller.get_rest_time_left())
	else:
		_hud.set_rest_time(-1.0)

func _setup_runtime() -> void:
	var wave_director = WaveDirectorScript.new()
	wave_director.setup(WaveDirectorConfigResource)

	_arena_controller = ArenaRunControllerScript.new()
	add_child(_arena_controller)
	_arena_controller.configure_runtime(self, _resolve_spawn_points())
	_arena_controller.setup(player, RewardPoolResource, wave_director, player.ensure_run_modifier_controller())

func _setup_ui() -> void:
	_hud = ArenaHudScript.new()
	add_child(_hud)

	_reward_ui = RewardSelectionUIScript.new()
	add_child(_reward_ui)

	_result_ui = RunResultUIScript.new()
	add_child(_result_ui)

	_pause_ui = PauseUIScene.instantiate()
	add_child(_pause_ui)

func _connect_signals() -> void:
	_arena_controller.wave_started.connect(_on_wave_started)
	_arena_controller.wave_cleared.connect(_on_wave_cleared)
	_arena_controller.reward_options_ready.connect(_on_reward_options_ready)
	_arena_controller.rest_started.connect(_on_rest_started)
	_arena_controller.run_completed.connect(_on_run_completed)
	_arena_controller.run_failed.connect(_on_run_failed)
	_reward_ui.card_selected.connect(_on_reward_card_selected)
	_result_ui.restart_requested.connect(_on_restart_requested)
	_pause_ui.resume_requested.connect(_on_pause_resume_requested)
	_pause_ui.exit_requested.connect(_on_pause_exit_requested)

func _toggle_pause_menu() -> bool:
	if _arena_controller == null or _pause_ui == null:
		return false
	if _arena_controller.current_state != ArenaRunController.RunState.IN_WAVE and _arena_controller.current_state != ArenaRunController.RunState.REST:
		return false
	_pause_ui.show_pause(player, _resolve_reward_cards_for_pause())
	get_tree().paused = true
	return true

func _resolve_reward_cards_for_pause() -> Array:
	if RewardPoolResource == null:
		return []
	return RewardPoolResource.cards.duplicate()

func _resolve_spawn_points() -> Array:
	var spawn_points: Array = []
	for child in get_children():
		if child is Marker2D and String(child.name).begins_with("SpawnPoint"):
			spawn_points.append(child)
	return spawn_points

func _on_wave_started(wave_index: int) -> void:
	if _pause_ui != null:
		_pause_ui.hide_pause()
	_reward_ui.hide_ui()
	_result_ui.hide_ui()
	_hud.set_wave(wave_index, WaveDirectorConfigResource.total_waves)
	_hud.set_state_text("Fight")

func _on_wave_cleared(_wave_index: int) -> void:
	_hud.set_state_text("Wave Cleared")

func _on_reward_options_ready(cards: Array) -> void:
	if _pause_ui != null:
		_pause_ui.hide_pause()
	_hud.set_state_text("Choose Reward")
	_reward_ui.present_cards(cards)

func _on_rest_started(seconds: float) -> void:
	_reward_ui.hide_ui()
	_hud.set_state_text("Rest")
	_hud.set_rest_time(seconds)

func _on_run_completed() -> void:
	if _pause_ui != null:
		_pause_ui.hide_pause()
	_reward_ui.hide_ui()
	_hud.set_state_text("Victory")
	_result_ui.show_victory(WaveDirectorConfigResource.total_waves)

func _on_run_failed(reached_wave: int) -> void:
	if _pause_ui != null:
		_pause_ui.hide_pause()
	_reward_ui.hide_ui()
	_hud.set_state_text("Defeat")
	_result_ui.show_defeat(reached_wave)

func _on_reward_card_selected(card_id: StringName) -> void:
	_arena_controller.select_reward_card(card_id)

func _on_restart_requested() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_pause_resume_requested() -> void:
	get_tree().paused = false
	if _pause_ui != null:
		_pause_ui.hide_pause()

func _on_pause_exit_requested() -> void:
	get_tree().paused = false
	if _pause_ui != null:
		_pause_ui.hide_pause()
	var scene_manager := _resolve_scene_manager_for_pause_exit()
	if scene_manager != null and scene_manager.has_method("change_scene"):
		scene_manager.change_scene(FALLBACK_EXIT_SCENE)
		return
	get_tree().change_scene_to_file(FALLBACK_EXIT_SCENE)

func _resolve_scene_manager_for_pause_exit() -> Node:
	if _scene_manager_override != null:
		return _scene_manager_override
	return get_tree().root.get_node_or_null("SceneManager")

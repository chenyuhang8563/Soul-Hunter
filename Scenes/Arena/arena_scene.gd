extends Node2D

const ArenaRunControllerScript := preload("res://Scenes/Arena/arena_run_controller.gd")
const ArenaHudScript := preload("res://Scenes/Arena/arena_hud.gd")
const ArenaDeveloperToolsPanelScript := preload("res://Scenes/Arena/developer_tools_panel.gd")
const RewardSelectionUIScript := preload("res://Scenes/Arena/reward_selection_ui.gd")
const RunResultUIScript := preload("res://Scenes/Arena/run_result_ui.gd")
const WaveDirectorScript := preload("res://Global/Roguelike/wave_director.gd")
const RewardPoolResource := preload("res://Data/Roguelike/reward_pool_basic.tres")
const WaveDirectorConfigResource := preload("res://Data/Roguelike/wave_director_basic.tres")

@onready var player = $Soldier

var _arena_controller: ArenaRunController = null
var _hud: ArenaHud = null
var _developer_tools = null
var _reward_ui: RewardSelectionUI = null
var _result_ui: RunResultUI = null

func _ready() -> void:
	_setup_runtime()
	_setup_ui()
	_connect_signals()
	_arena_controller.start_run()

func _process(_delta: float) -> void:
	if _arena_controller == null or _hud == null:
		return
	if _arena_controller.current_state == ArenaRunController.RunState.REST:
		_hud.set_rest_time(_arena_controller.get_rest_time_left())
	else:
		_hud.set_rest_time(-1.0)

func _unhandled_input(event: InputEvent) -> void:
	if event == null or not event.is_action_pressed("developer_tools_toggle"):
		return
	_toggle_developer_tools_visibility()
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()

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
	_hud.set_buff_summary_text("")

	_developer_tools = ArenaDeveloperToolsPanelScript.new()
	add_child(_developer_tools)
	_developer_tools.bind(_arena_controller, _arena_controller.get_run_modifier_controller(), WaveDirectorConfigResource.total_waves)

	_reward_ui = RewardSelectionUIScript.new()
	add_child(_reward_ui)

	_result_ui = RunResultUIScript.new()
	add_child(_result_ui)

func _connect_signals() -> void:
	_arena_controller.wave_started.connect(_on_wave_started)
	_arena_controller.wave_cleared.connect(_on_wave_cleared)
	_arena_controller.reward_options_ready.connect(_on_reward_options_ready)
	_arena_controller.rest_started.connect(_on_rest_started)
	_arena_controller.run_completed.connect(_on_run_completed)
	_arena_controller.run_failed.connect(_on_run_failed)
	_developer_tools.buff_value_changed.connect(_on_developer_buff_value_changed)
	_developer_tools.jump_to_rest_requested.connect(_on_jump_to_rest_requested)
	_developer_tools.developer_mode_toggled.connect(_on_developer_mode_toggled)
	_reward_ui.card_selected.connect(_on_reward_card_selected)
	_result_ui.restart_requested.connect(_on_restart_requested)

func _resolve_spawn_points() -> Array:
	var spawn_points: Array = []
	for child in get_children():
		if child is Marker2D and String(child.name).begins_with("SpawnPoint"):
			spawn_points.append(child)
	return spawn_points

func _on_wave_started(wave_index: int) -> void:
	_reward_ui.hide_ui()
	_result_ui.hide_ui()
	_hud.set_wave(wave_index, WaveDirectorConfigResource.total_waves)
	_hud.set_state_text("Fight")

func _on_wave_cleared(_wave_index: int) -> void:
	_hud.set_state_text("Wave Cleared")

func _on_reward_options_ready(cards: Array) -> void:
	_hud.set_state_text("Choose Reward")
	_reward_ui.present_cards(cards)

func _on_rest_started(seconds: float) -> void:
	_reward_ui.hide_ui()
	_hud.set_state_text("Rest")
	_hud.set_rest_time(seconds)

func _on_run_completed() -> void:
	_reward_ui.hide_ui()
	_hud.set_state_text("Victory")
	_result_ui.show_victory(WaveDirectorConfigResource.total_waves)

func _on_run_failed(reached_wave: int) -> void:
	_reward_ui.hide_ui()
	_hud.set_state_text("Defeat")
	_result_ui.show_defeat(reached_wave)

func _on_reward_card_selected(card_id: StringName) -> void:
	if _arena_controller.select_reward_card(card_id):
		_refresh_selected_buff_titles()

func _on_developer_buff_value_changed(card_id: StringName, value: float) -> void:
	var modifier_controller := _arena_controller.get_run_modifier_controller()
	if modifier_controller == null:
		return
	modifier_controller.set_developer_buff_value(card_id, value)
	_refresh_selected_buff_titles()

func _on_jump_to_rest_requested(wave_index: int) -> void:
	if not _arena_controller.jump_to_rest_after_wave(wave_index):
		return
	_reward_ui.hide_ui()
	_result_ui.hide_ui()
	_hud.set_wave(_arena_controller.current_wave, WaveDirectorConfigResource.total_waves)
	_hud.set_state_text("Rest")
	_hud.set_rest_time(_arena_controller.get_rest_time_left())

func _on_developer_mode_toggled(enabled: bool) -> void:
	DeveloperMode.set_enabled(enabled)

func _on_restart_requested() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _toggle_developer_tools_visibility() -> void:
	if _developer_tools == null:
		return
	_developer_tools.visible = not _developer_tools.visible

func _refresh_selected_buff_titles() -> void:
	if _hud == null or _arena_controller == null:
		return
	var modifier_controller := _arena_controller.get_run_modifier_controller()
	if modifier_controller == null:
		_hud.set_buff_summary_text("")
		return
	_hud.set_buff_summary_text(modifier_controller.get_hud_buff_summary_text())

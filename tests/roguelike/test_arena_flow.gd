extends GutTest

const REWARD_EFFECT_SCRIPT_PATH := "res://Global/Roguelike/reward_effect_definition.gd"
const REWARD_CARD_SCRIPT_PATH := "res://Global/Roguelike/reward_card_definition.gd"
const REWARD_POOL_SCRIPT_PATH := "res://Global/Roguelike/reward_pool_definition.gd"
const WAVE_CONFIG_SCRIPT_PATH := "res://Global/Roguelike/wave_director_config.gd"
const WAVE_DIRECTOR_SCRIPT_PATH := "res://Global/Roguelike/wave_director.gd"
const RUN_MODIFIER_CONTROLLER_SCRIPT_PATH := "res://Character/Common/run_modifier_controller.gd"
const ARENA_RUN_CONTROLLER_SCRIPT_PATH := "res://Scenes/Arena/arena_run_controller.gd"
const ARENA_SCENE_PATH := "res://Scenes/arena.tscn"


class FakeArenaPlayer:
	extends Node2D

	signal damage_dealt(target, final_damage)
	signal dash_finished(start_position, end_position)

	var healed_amount := 0.0
	var team_id := 0

	func heal(amount: float) -> void:
		healed_amount += amount

	func get_team_id() -> int:
		return team_id


class FakeEnemy:
	extends Node2D

	var team_id := 1
	var damage_received := 0.0
	var hit_count := 0
	var alive := true

	func apply_damage(amount: float, _source: CharacterBody2D = null) -> void:
		damage_received += amount
		hit_count += 1

	func get_team_id() -> int:
		return team_id

	func is_alive() -> bool:
		return alive


class FakeSceneManager:
	extends CanvasLayer

	var changed_paths: Array[String] = []

	func change_scene(path: String) -> void:
		changed_paths.append(path)


func test_run_modifier_dash_path_damage_hits_each_enemy_once() -> void:
	var reward_effect_script = load(REWARD_EFFECT_SCRIPT_PATH)
	var reward_card_script = load(REWARD_CARD_SCRIPT_PATH)
	var run_modifier_controller_script = load(RUN_MODIFIER_CONTROLLER_SCRIPT_PATH)

	assert_not_null(run_modifier_controller_script, "RunModifierController script should exist")
	assert_not_null(reward_effect_script, "RewardEffectDefinition script should exist")
	assert_not_null(reward_card_script, "RewardCardDefinition script should exist")

	if run_modifier_controller_script == null or reward_effect_script == null or reward_card_script == null:
		return

	var host: FakeArenaPlayer = autofree(FakeArenaPlayer.new())
	add_child(host)
	var controller = run_modifier_controller_script.new()
	controller.setup(host)

	var dash_damage = reward_effect_script.new()
	dash_damage.effect_type = reward_effect_script.EffectType.DASH_PATH_DAMAGE
	dash_damage.value = 10.0

	var card = reward_card_script.new()
	card.id = &"dash_line"
	card.title = "Dash Slash"
	card.effects = [dash_damage]
	controller.apply_reward_card(card)

	var on_path_enemy: FakeEnemy = autofree(FakeEnemy.new())
	on_path_enemy.global_position = Vector2(50.0, 0.0)
	on_path_enemy.add_to_group("arena_enemy")
	add_child(on_path_enemy)

	var near_path_enemy: FakeEnemy = autofree(FakeEnemy.new())
	near_path_enemy.global_position = Vector2(75.0, 8.0)
	near_path_enemy.add_to_group("arena_enemy")
	add_child(near_path_enemy)

	var off_path_enemy: FakeEnemy = autofree(FakeEnemy.new())
	off_path_enemy.global_position = Vector2(60.0, 30.0)
	off_path_enemy.add_to_group("arena_enemy")
	add_child(off_path_enemy)

	host.dash_finished.emit(Vector2.ZERO, Vector2(100.0, 0.0))

	assert_eq(on_path_enemy.damage_received, 10.0, "Enemy on dash path should take dash reward damage")
	assert_eq(near_path_enemy.damage_received, 10.0, "Enemy inside the path width should also take damage")
	assert_eq(off_path_enemy.damage_received, 0.0, "Enemy outside the path width should not be hit")
	assert_eq(on_path_enemy.hit_count, 1, "Dash path damage should hit each enemy once")
	assert_eq(near_path_enemy.hit_count, 1, "Dash path damage should hit nearby path enemy once")


func test_arena_run_controller_cycles_wave_reward_and_rest() -> void:
	var arena_run_controller_script = load(ARENA_RUN_CONTROLLER_SCRIPT_PATH)
	var reward_pool = _build_reward_pool()
	var wave_director = _build_wave_director(2)

	assert_not_null(arena_run_controller_script, "ArenaRunController script should exist")
	assert_not_null(reward_pool, "Reward pool helper should create a reward pool")
	assert_not_null(wave_director, "Wave director helper should create a wave director")

	if arena_run_controller_script == null or reward_pool == null or wave_director == null:
		return

	var player: FakeArenaPlayer = autofree(FakeArenaPlayer.new())
	add_child(player)

	var controller = autofree(arena_run_controller_script.new())
	add_child(controller)
	controller.setup(player, reward_pool, wave_director)

	var offered_cards_ref := {"cards": []}
	var rest_seconds_ref := {"value": -1.0}
	controller.reward_options_ready.connect(func(cards: Array) -> void:
		offered_cards_ref["cards"] = cards
	)
	controller.rest_started.connect(func(seconds: float) -> void:
		rest_seconds_ref["value"] = seconds
	)

	controller.start_run()
	assert_eq(controller.current_wave, 1, "Run should start at wave 1")
	assert_eq(controller.current_state, controller.RunState.IN_WAVE, "Run should enter wave state on start")

	controller.complete_current_wave()
	assert_eq(controller.current_state, controller.RunState.REWARD_SELECTION, "Clearing a wave should open reward selection")
	assert_eq((offered_cards_ref["cards"] as Array).size(), 3, "Wave clear should offer three reward cards")

	var offered_cards: Array = offered_cards_ref["cards"] as Array
	controller.select_reward_card(offered_cards[0].id)
	assert_eq(controller.current_state, controller.RunState.REST, "Picking a card should enter rest state")
	assert_eq(rest_seconds_ref["value"], 3.0, "Rest state should start with a 3 second timer")

	controller.advance_rest_time(3.0)
	assert_eq(controller.current_wave, 2, "Rest completion should begin the next wave")
	assert_eq(controller.current_state, controller.RunState.IN_WAVE, "Rest completion should return to wave state")


func test_arena_run_controller_finishes_after_final_wave() -> void:
	var arena_run_controller_script = load(ARENA_RUN_CONTROLLER_SCRIPT_PATH)
	var reward_pool = _build_reward_pool()
	var wave_director = _build_wave_director(1)

	assert_not_null(arena_run_controller_script, "ArenaRunController script should exist")
	assert_not_null(reward_pool, "Reward pool helper should create a reward pool")
	assert_not_null(wave_director, "Wave director helper should create a wave director")

	if arena_run_controller_script == null or reward_pool == null or wave_director == null:
		return

	var player: FakeArenaPlayer = autofree(FakeArenaPlayer.new())
	add_child(player)

	var controller = autofree(arena_run_controller_script.new())
	add_child(controller)
	controller.setup(player, reward_pool, wave_director)

	var victory_events: Array = []
	controller.run_completed.connect(func() -> void:
		victory_events.append(true)
	)

	controller.start_run()
	controller.complete_current_wave()

	assert_eq(controller.current_state, controller.RunState.VICTORY, "Final wave clear should end the run in victory")
	assert_eq(victory_events.size(), 1, "Victory signal should fire exactly once")


func test_arena_scene_pause_toggle_only_works_in_wave_and_rest() -> void:
	var arena_scene = load(ARENA_SCENE_PATH)
	assert_not_null(arena_scene, "Arena scene should exist")
	if arena_scene == null:
		return

	var arena = autofree(arena_scene.instantiate())
	add_child(arena)

	arena._arena_controller.current_state = arena._arena_controller.RunState.IN_WAVE
	assert_true(arena._toggle_pause_menu(), "Pause should open during wave")
	assert_true(get_tree().paused, "Opening pause should pause the tree")

	arena._on_pause_resume_requested()
	assert_false(get_tree().paused, "Resuming should unpause the tree")

	arena._arena_controller.current_state = arena._arena_controller.RunState.REWARD_SELECTION
	assert_false(arena._toggle_pause_menu(), "Pause should not open during reward selection")

	arena._arena_controller.current_state = arena._arena_controller.RunState.REST
	assert_true(arena._toggle_pause_menu(), "Pause should open during rest")
	get_tree().paused = false


func test_arena_scene_exit_request_uses_scene_manager_when_available() -> void:
	var arena_scene = load(ARENA_SCENE_PATH)
	assert_not_null(arena_scene, "Arena scene should exist")
	if arena_scene == null:
		return

	var arena = autofree(arena_scene.instantiate())
	add_child(arena)

	var fake_scene_manager: FakeSceneManager = autofree(FakeSceneManager.new())
	arena._scene_manager_override = fake_scene_manager
	get_tree().paused = true

	arena._on_pause_exit_requested()

	assert_false(get_tree().paused, "Exit should clear pause before leaving the scene")
	assert_eq(fake_scene_manager.changed_paths.size(), 1, "Exit should request one scene change when SceneManager is available")


func _build_reward_pool():
	var reward_effect_script = load(REWARD_EFFECT_SCRIPT_PATH)
	var reward_card_script = load(REWARD_CARD_SCRIPT_PATH)
	var reward_pool_script = load(REWARD_POOL_SCRIPT_PATH)
	if reward_effect_script == null or reward_card_script == null or reward_pool_script == null:
		return null

	var reward_pool = reward_pool_script.new()
	for index in range(4):
		var effect = reward_effect_script.new()
		effect.effect_type = reward_effect_script.EffectType.STAT_ADD
		effect.stat_id = &"light_attack_damage"
		effect.value = float(index + 1)

		var card = reward_card_script.new()
		card.id = StringName("reward_%s" % index)
		card.title = "Reward %s" % index
		card.effects = [effect]
		reward_pool.cards.append(card)

	return reward_pool


func _build_wave_director(total_waves: int):
	var wave_config_script = load(WAVE_CONFIG_SCRIPT_PATH)
	var wave_director_script = load(WAVE_DIRECTOR_SCRIPT_PATH)
	if wave_config_script == null or wave_director_script == null:
		return null

	var config = wave_config_script.new()
	config.total_waves = total_waves
	config.base_enemy_count = 2
	config.enemy_count_per_wave = 1
	config.health_scale_per_wave = 0.1
	config.attack_scale_per_wave = 0.05
	config.move_speed_scale_per_wave = 0.02

	var director = wave_director_script.new()
	director.setup(config)
	return director

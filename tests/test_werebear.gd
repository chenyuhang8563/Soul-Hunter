extends GutTest

const WerebearScene := preload("res://Character/Werebear/werebear.tscn")
const SoldierScene := preload("res://Character/Soldier/soldier.tscn")
const BossAIModulePath := "res://Character/Common/boss_ai_module.gd"
const WerebearEnrageBuffScript := preload("res://Character/Common/Buffs/werebear_enrage_buff.gd")
const WerebearKnockbackResistBuffScript := preload("res://Character/Common/Buffs/werebear_knockback_resist_buff.gd")
const BossFightBgmPath := "res://Assets/SFX/boss_fight.wav"


class FakeAudioManager extends Node:
	var last_bgm_stream: AudioStream = null

	func _enter_tree() -> void:
		add_to_group(&"audio_manager_service")

	func play_bgm_stream(stream: AudioStream) -> void:
		last_bgm_stream = stream


class FakeDamageSource extends CharacterBody2D:
	func _init(start_position: Vector2 = Vector2.ZERO) -> void:
		global_position = start_position


func _measure_knockback_distance(werebear, source: CharacterBody2D) -> float:
	werebear.global_position = Vector2.ZERO
	werebear.knockback_velocity = 0.0
	werebear.lifecycle_state.on_damaged(5.0, werebear.health.current_health, werebear.health.max_health, source)
	var start_x: float = werebear.global_position.x
	for _frame in range(30):
		await get_tree().physics_frame
		if is_zero_approx(werebear.knockback_velocity):
			break
	return absf(werebear.global_position.x - start_x)


func before_each() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false


func after_each() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false


func test_werebear_initializes_boss_runtime_defaults() -> void:
	var werebear = add_child_autofree(WerebearScene.instantiate())
	await get_tree().process_frame
	await get_tree().physics_frame

	var visual_scope := werebear.get_node("VisualScope") as Area2D
	var attack_scope := werebear.get_node("AttackScope") as Area2D

	assert_eq(werebear.phase_two_health_ratio, 0.5)
	assert_true(werebear.boss_ai_enabled)
	assert_not_null(werebear.attack_module, "Werebear should create an attack module during setup.")
	assert_not_null(werebear.ai_module, "Werebear should create an AI module during setup.")
	assert_eq(werebear.current_phase, 1)
	assert_false(werebear.phase_two_triggered)
	assert_eq(werebear.team_id, 1)
	assert_true(visual_scope.monitoring, "Boss AI should enable target acquisition when not player-controlled.")
	assert_true(attack_scope.monitoring, "Boss AI should enable attack scope when active.")


func test_werebear_exports_reactive_backstep_distance_and_passes_it_to_the_attack_module() -> void:
	var werebear = WerebearScene.instantiate()
	werebear.reactive_backstep_distance = 28.0
	werebear.reactive_backstep_chance = 0.65
	add_child_autofree(werebear)
	await get_tree().process_frame
	await get_tree().physics_frame

	assert_eq(werebear.reactive_backstep_distance, 28.0)
	assert_eq(werebear.reactive_backstep_chance, 0.65)
	assert_not_null(werebear.attack_module, "Werebear should initialize an attack module during setup.")
	assert_not_null(werebear.ai_module, "Werebear should initialize an AI module during setup.")
	if werebear.attack_module == null:
		return
	assert_eq(
		werebear.attack_module.get("reactive_backstep_distance"),
		28.0,
		"Werebear should push the exported backstep distance into the boss attack module so it can be tuned in the editor."
	)
	if werebear.ai_module != null:
		assert_eq(
			werebear.ai_module.get("reactive_backstep_chance"),
			0.65,
			"Werebear should push the exported backstep chance into the boss AI module so the opener probability can be tuned in the editor."
		)


func test_werebear_animation_tracks_use_frame_instead_of_frame_coords() -> void:
	var werebear = add_child_autofree(WerebearScene.instantiate())
	await get_tree().process_frame

	var animation_player := werebear.get_node("AnimationPlayer") as AnimationPlayer
	assert_not_null(animation_player, "Werebear scene should expose an AnimationPlayer.")
	if animation_player == null:
		return

	for animation_name in animation_player.get_animation_list():
		if animation_name == &"RESET":
			continue
		var animation := animation_player.get_animation(animation_name)
		assert_not_null(animation, "Werebear should provide every requested animation resource.")
		if animation == null:
			continue
		for track_index in range(animation.get_track_count()):
			var track_path := String(animation.track_get_path(track_index))
			assert_false(
				track_path.ends_with("Sprite2D:frame_coords"),
				"Werebear animation '%s' should no longer use Sprite2D:frame_coords." % String(animation_name)
			)


func test_werebear_switches_to_phase_two_at_threshold() -> void:
	var werebear = add_child_autofree(WerebearScene.instantiate())
	await get_tree().process_frame
	await get_tree().physics_frame

	werebear.health.current_health = werebear.health.max_health * werebear.phase_two_health_ratio
	werebear._update_boss_phase()

	assert_eq(werebear.current_phase, 2)
	assert_true(werebear.phase_two_triggered)


func test_werebear_prefers_dedicated_boss_ai_module_and_notifies_phase_two() -> void:
	var werebear = add_child_autofree(WerebearScene.instantiate())
	await get_tree().process_frame
	await get_tree().physics_frame

	var ai_module = werebear.ai_module
	assert_not_null(ai_module, "Werebear should initialize an AI module during setup.")
	if ai_module == null:
		return

	assert_eq(
		ai_module.get_script().resource_path,
		BossAIModulePath,
		"Werebear should switch from the temporary generic AI fallback to the dedicated boss AI module."
	)
	assert_true(ai_module.has_method("is_phase_two"), "Boss AI should expose phase state to Werebear.")
	if not ai_module.has_method("is_phase_two"):
		return

	werebear.health.current_health = werebear.health.max_health * werebear.phase_two_health_ratio
	werebear._update_boss_phase()

	assert_true(ai_module.is_phase_two(), "Crossing the boss threshold should notify the dedicated boss AI module.")


func test_player_control_switches_werebear_out_of_boss_ai_mode() -> void:
	var werebear = add_child_autofree(WerebearScene.instantiate())
	await get_tree().process_frame
	await get_tree().physics_frame

	var visual_scope := werebear.get_node("VisualScope") as Area2D
	var attack_scope := werebear.get_node("AttackScope") as Area2D

	werebear.set_player_controlled(true)
	await get_tree().process_frame

	assert_eq(werebear.team_id, 0)
	assert_false(visual_scope.monitoring, "Player-controlled Werebear should not keep boss target acquisition active.")
	assert_true(attack_scope.monitoring, "Player-controlled Werebear should still be able to attack nearby targets.")


func test_werebear_possession_transfer_keeps_the_new_host_on_the_player_team() -> void:
	var werebear = add_child_autofree(WerebearScene.instantiate())
	var new_host = add_child_autofree(SoldierScene.instantiate())
	var enemy = add_child_autofree(SoldierScene.instantiate())

	werebear.global_position = Vector2.ZERO
	new_host.global_position = Vector2(16.0, 0.0)
	enemy.global_position = Vector2(32.0, 0.0)

	await get_tree().process_frame
	await get_tree().physics_frame

	werebear.set_player_controlled(true)
	werebear.team_id = 0
	new_host.set_player_controlled(false)
	new_host.team_id = 1
	enemy.set_player_controlled(false)
	enemy.team_id = 1
	new_host.health.current_health = new_host.health.max_health * 0.1

	assert_true(
		new_host.can_be_possessed_now(),
		"Test setup should put the new host below the possession health threshold."
	)
	assert_true(
		new_host.receive_possession_from(werebear),
		"Werebear should be able to hand off player control to another valid host."
	)
	assert_eq(
		new_host.team_id,
		0,
		"The new host should stay on the player team after possession instead of inheriting the Werebear's enemy AI team on release."
	)
	assert_true(
		new_host.attack_module._is_valid_damage_target(enemy),
		"A freshly possessed host should still be able to treat nearby enemies as attack targets."
	)
	assert_true(
		enemy.ai_module.is_valid_enemy(new_host),
		"Enemy AI should still recognize the newly possessed host as hostile."
	)


func test_werebear_enrage_reuses_possession_red_overlay() -> void:
	var werebear = add_child_autofree(WerebearScene.instantiate())
	await get_tree().process_frame
	await get_tree().physics_frame

	werebear.add_buff(WerebearEnrageBuffScript.new())
	werebear._sync_possession_combo_overlay()

	var overlay := werebear.get_node_or_null("PossessionComboOverlay") as Sprite2D
	assert_not_null(overlay, "Werebear enrage should create the same red overlay node used by possession haste.")
	if overlay == null:
		return

	assert_true(overlay.visible, "Werebear enrage should show the red overlay.")
	assert_eq(overlay.self_modulate, Color(1.0, 0.45, 0.45, 0.28))


func test_werebear_phase_two_applies_enrage_once_and_resyncs_boss_walk_speed() -> void:
	var werebear = add_child_autofree(WerebearScene.instantiate())
	await get_tree().process_frame
	await get_tree().physics_frame

	var ai_module = werebear.ai_module
	assert_not_null(ai_module, "Werebear should initialize a boss AI module.")
	if ai_module == null:
		return

	var initial_walk_speed := float(ai_module.get("walk_speed"))
	werebear.health.current_health = werebear.health.max_health * werebear.phase_two_health_ratio
	werebear._update_boss_phase()

	assert_true(werebear.buff_controller.has_buff(&"werebear_enrage"))

	var enrage_count := 0
	for buff in werebear.buff_controller.get_active_buffs():
		if buff != null and buff.stack_key == &"werebear_enrage":
			enrage_count += 1
	assert_eq(enrage_count, 1, "Werebear should only add one permanent enrage buff.")

	var expected_walk_speed: float = werebear.get_player_move_speed() * 0.5 * 1.15
	assert_eq(float(ai_module.get("walk_speed")), expected_walk_speed)
	assert_true(float(ai_module.get("walk_speed")) > initial_walk_speed)

	werebear._update_boss_phase()

	enrage_count = 0
	for buff in werebear.buff_controller.get_active_buffs():
		if buff != null and buff.stack_key == &"werebear_enrage":
			enrage_count += 1
	assert_eq(enrage_count, 1, "Repeated phase-two updates should not duplicate enrage.")


func test_werebear_does_not_gain_knockback_resist_before_phase_two() -> void:
	var werebear = add_child_autofree(WerebearScene.instantiate())
	await get_tree().process_frame
	await get_tree().physics_frame

	assert_false(werebear.buff_controller.has_buff(&"werebear_knockback_resist"))


func test_werebear_phase_two_applies_permanent_knockback_resist_buff() -> void:
	var werebear = add_child_autofree(WerebearScene.instantiate())
	await get_tree().process_frame
	await get_tree().physics_frame

	werebear.health.current_health = werebear.health.max_health * werebear.phase_two_health_ratio
	werebear._update_boss_phase()

	assert_true(werebear.buff_controller.has_buff(&"werebear_knockback_resist"))

	var resist_count := 0
	for buff in werebear.buff_controller.get_active_buffs():
		if buff != null and buff.stack_key == &"werebear_knockback_resist":
			resist_count += 1
	assert_eq(resist_count, 1, "Werebear should only add one permanent knockback-resist buff in phase two.")

	werebear._update_boss_phase()

	resist_count = 0
	for buff in werebear.buff_controller.get_active_buffs():
		if buff != null and buff.stack_key == &"werebear_knockback_resist":
			resist_count += 1
	assert_eq(resist_count, 1, "Repeated phase-two updates should not duplicate knockback resist.")


func test_werebear_phase_two_knockback_resist_helper_is_idempotent() -> void:
	var werebear = add_child_autofree(WerebearScene.instantiate())
	await get_tree().process_frame
	await get_tree().physics_frame

	werebear._apply_phase_two_knockback_resist()
	werebear._apply_phase_two_knockback_resist()

	var resist_count := 0
	for buff in werebear.buff_controller.get_active_buffs():
		if buff != null and buff.stack_key == &"werebear_knockback_resist":
			resist_count += 1

	assert_eq(resist_count, 1, "Werebear should keep only one permanent knockback-resist buff when phase-two resist is applied repeatedly.")
	assert_eq(
		float(werebear.get_stat_value(&"knockback_taken_multiplier", 1.0)),
		0.5,
		"Werebear's effective knockback multiplier should stay at the permanent half-knockback value."
	)


func test_werebear_phase_two_halves_knockback_velocity() -> void:
	var werebear = add_child_autofree(WerebearScene.instantiate())
	var source = add_child_autofree(FakeDamageSource.new(Vector2(-12.0, 0.0)))
	await get_tree().process_frame
	await get_tree().physics_frame

	werebear.global_position = Vector2.ZERO
	werebear.knockback_velocity = 0.0
	werebear.lifecycle_state.on_damaged(5.0, werebear.health.current_health, werebear.health.max_health, source)
	var phase_one_knockback := absf(werebear.knockback_velocity)

	werebear.knockback_velocity = 0.0
	werebear.health.current_health = werebear.health.max_health * werebear.phase_two_health_ratio
	werebear._update_boss_phase()
	werebear.lifecycle_state.on_damaged(5.0, werebear.health.current_health, werebear.health.max_health, source)
	var phase_two_knockback := absf(werebear.knockback_velocity)

	assert_eq(phase_one_knockback, werebear.KNOCKBACK_VELOCITY)
	assert_eq(phase_two_knockback, werebear.KNOCKBACK_VELOCITY * 0.5)


func test_werebear_phase_two_halves_knockback_travel_distance() -> void:
	var phase_one_werebear = add_child_autofree(WerebearScene.instantiate())
	var phase_one_source = add_child_autofree(FakeDamageSource.new(Vector2(-12.0, 0.0)))
	await get_tree().process_frame
	await get_tree().physics_frame

	var phase_one_distance: float = await _measure_knockback_distance(phase_one_werebear, phase_one_source)

	var phase_two_werebear = add_child_autofree(WerebearScene.instantiate())
	var phase_two_source = add_child_autofree(FakeDamageSource.new(Vector2(-12.0, 0.0)))
	await get_tree().process_frame
	await get_tree().physics_frame
	phase_two_werebear.health.current_health = phase_two_werebear.health.max_health * phase_two_werebear.phase_two_health_ratio
	phase_two_werebear._update_boss_phase()

	var phase_two_distance: float = await _measure_knockback_distance(phase_two_werebear, phase_two_source)

	assert_gt(phase_one_distance, 0.0)
	assert_gt(phase_two_distance, phase_one_distance * 0.4)
	assert_lt(phase_two_distance, phase_one_distance * 0.6)


func test_werebear_initialization_switches_bgm_to_boss_fight() -> void:
	var fake_audio_manager: FakeAudioManager = add_child_autofree(FakeAudioManager.new())
	var werebear = add_child_autofree(WerebearScene.instantiate())
	await get_tree().process_frame
	await get_tree().physics_frame

	assert_not_null(fake_audio_manager.last_bgm_stream, "Werebear should request boss BGM during initialization.")
	if fake_audio_manager.last_bgm_stream == null:
		return
	assert_eq(fake_audio_manager.last_bgm_stream.resource_path, BossFightBgmPath)


func test_werebear_without_boss_ai_does_not_request_boss_bgm() -> void:
	var fake_audio_manager: FakeAudioManager = add_child_autofree(FakeAudioManager.new())
	var werebear = WerebearScene.instantiate()
	werebear.boss_ai_enabled = false
	add_child_autofree(werebear)
	await get_tree().process_frame
	await get_tree().physics_frame

	assert_null(fake_audio_manager.last_bgm_stream, "Non-boss Werebear contexts should not request the boss battle BGM.")

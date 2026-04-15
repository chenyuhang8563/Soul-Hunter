extends GutTest

const SoldierScene := preload("res://Character/Soldier/soldier.tscn")
const ArcherScene := preload("res://Character/Archer/archer.tscn")
const SwordsmanScene := preload("res://Character/Swordsman/swordsman.tscn")
const WINDUP_SECONDS := 0.2
const WINDUP_EPSILON := 0.001

func _spawn_character(scene: PackedScene, player_controlled := true):
	var character = add_child_autofree(scene.instantiate())
	await get_tree().process_frame
	character.set_player_controlled(player_controlled)
	await get_tree().process_frame
	return character

func _has_property(target: Object, property_name: String) -> bool:
	if target == null:
		return false
	for property_data in target.get_property_list():
		if String(property_data.get("name", "")) == property_name:
			return true
	return false

func _apply_attack_speed_multiplier(character: Node, multiplier: float) -> bool:
	if character == null:
		return false
	var attack_module = character.get("attack_module")
	if attack_module != null and attack_module.has_method("set_attack_speed_multiplier"):
		attack_module.call("set_attack_speed_multiplier", multiplier)
		return true
	if _has_property(attack_module, "attack_speed_multiplier"):
		attack_module.set("attack_speed_multiplier", multiplier)
		return true
	var stats = character.get("stats")
	if _has_property(stats, "attack_speed_multiplier"):
		stats.set("attack_speed_multiplier", multiplier)
		if character.has_method("_refresh_cached_stat_state"):
			character.call("_refresh_cached_stat_state")
		return true
	return false

func test_soldier_light_attack_first_hit_uses_shared_windup() -> void:
	var soldier = await _spawn_character(SoldierScene, true)

	soldier.attack_module._start_light_attack()

	assert_false(soldier.attack_module.damage_events.is_empty(), "Soldier light attack should queue damage.")
	if soldier.attack_module.damage_events.is_empty():
		return

	assert_almost_eq(
		float(soldier.attack_module.damage_events[0]["trigger_time"]),
		WINDUP_SECONDS,
		WINDUP_EPSILON,
		"Every first attack hit should start from the shared 0.2s windup."
	)

func test_ai_soldier_light_attack_first_hit_uses_shared_windup() -> void:
	var soldier = await _spawn_character(SoldierScene, false)

	soldier.attack_module._start_light_attack()

	assert_false(soldier.attack_module.damage_events.is_empty(), "AI soldier light attack should queue damage.")
	if soldier.attack_module.damage_events.is_empty():
		return

	assert_almost_eq(
		float(soldier.attack_module.damage_events[0]["trigger_time"]),
		WINDUP_SECONDS,
		WINDUP_EPSILON,
		"AI melee attackers should share the same 0.2s first-hit windup."
	)

	soldier.attack_module.force_stop()
	soldier.attack_module.set_attack_cooldown(0.0)
	soldier.attack_module._start_hard_attack()

	assert_false(soldier.attack_module.damage_events.is_empty(), "AI soldier hard attack should queue damage.")
	if soldier.attack_module.damage_events.is_empty():
		return

	assert_almost_eq(
		float(soldier.attack_module.damage_events[0]["trigger_time"]),
		WINDUP_SECONDS,
		WINDUP_EPSILON,
		"AI hard melee should share the same 0.2s first-hit windup."
	)

func test_soldier_hard_and_ultimate_first_hit_use_shared_windup() -> void:
	var soldier = await _spawn_character(SoldierScene, true)

	soldier.attack_module._start_hard_attack()

	assert_false(soldier.attack_module.damage_events.is_empty(), "Soldier hard attack should queue damage.")
	if soldier.attack_module.damage_events.is_empty():
		return

	assert_almost_eq(
		float(soldier.attack_module.damage_events[0]["trigger_time"]),
		WINDUP_SECONDS,
		WINDUP_EPSILON,
		"Soldier hard attack should start from the shared 0.2s windup."
	)

	soldier.attack_module.force_stop()
	soldier.attack_module.set_attack_cooldown(0.0)
	soldier.attack_module._start_ultimate_attack()

	assert_false(soldier.attack_module.damage_events.is_empty(), "Soldier ultimate attack should queue damage.")
	if soldier.attack_module.damage_events.is_empty():
		return

	assert_almost_eq(
		float(soldier.attack_module.damage_events[0]["trigger_time"]),
		WINDUP_SECONDS,
		WINDUP_EPSILON,
		"Soldier ultimate attack should start from the shared 0.2s windup."
	)

func test_attack_speed_multiplier_scales_real_attack_runtime() -> void:
	var soldier = await _spawn_character(SoldierScene, true)
	var speed_applied := _apply_attack_speed_multiplier(soldier, 2.0)
	var expected_finish_seconds := 0.24

	assert_true(
		speed_applied,
		"Attack-speed runtime regression needs a configurable attack_speed_multiplier state."
	)
	if not speed_applied:
		return

	soldier.attack_module._start_light_attack()
	soldier.attack_module.update(expected_finish_seconds - 0.01, null, false)

	assert_true(
		soldier.attack_module.is_attacking(),
		"Soldier light attack should still be active just before the 0.24s player-controlled finish boundary."
	)

	soldier.attack_module.update(0.02, null, false)

	assert_false(
		soldier.attack_module.is_attacking(),
		"Soldier light attack should finish just after the 0.24s player-controlled boundary at 2.0x attack speed."
	)

func test_attack_cooldown_still_gates_immediate_reattack() -> void:
	var soldier = await _spawn_character(SoldierScene, true)

	soldier.attack_module._start_light_attack()
	soldier.attack_module.update(0.5, null, false)

	assert_false(soldier.attack_module.is_attacking(), "Soldier light attack should have finished before cooldown gating is checked.")
	assert_gt(
		soldier.attack_module.attack_cooldown_left,
		0.0,
		"Finishing an attack should still leave cooldown time for current setup callers."
	)
	assert_false(
		soldier.attack_module.can_start_attack(),
		"Base attack modules should still respect attack_cooldown_left until later migration tasks remove cooldown compatibility."
	)

	soldier.attack_module._start_light_attack()

	assert_false(
		soldier.attack_module.is_attacking(),
		"Immediate reattack should stay blocked while cooldown compatibility is still required."
	)

func test_attack_speed_multiplier_syncs_attack_animation_speed_from_owner_animation_player() -> void:
	var soldier = await _spawn_character(SoldierScene, true)

	assert_not_null(
		soldier.animation_player,
		"Soldier scene should expose an animation_player for the base-module fallback path."
	)
	if soldier.animation_player == null:
		return

	assert_true(
		soldier.attack_module.has_method("set_attack_speed_multiplier"),
		"Attack modules should expose set_attack_speed_multiplier() for live attack-speed updates."
	)
	if not soldier.attack_module.has_method("set_attack_speed_multiplier"):
		return

	soldier.attack_module.set_attack_cooldown(0.0)
	soldier.attack_module.call("set_attack_speed_multiplier", 1.5)
	soldier.attack_module._start_light_attack()

	assert_eq(
		soldier.animation_player.speed_scale,
		1.5,
		"Starting an attack should sync playback speed even when the module resolved its AnimationPlayer from the owner."
	)

	soldier.attack_module.call("set_attack_speed_multiplier", 2.0)

	assert_eq(
		soldier.animation_player.speed_scale,
		2.0,
		"Changing the attack-speed multiplier mid-attack should update playback speed immediately."
	)

	soldier.attack_module.update(0.25, null, false)

	assert_false(
		soldier.attack_module.is_attacking(),
		"Soldier light attack should finish once its runtime is scaled by the attack-speed multiplier."
	)
	assert_eq(
		soldier.animation_player.speed_scale,
		1.0,
		"Finishing an attack should restore normal animation playback speed."
	)

	soldier.attack_module._start_light_attack()
	soldier.attack_module.force_stop()

	assert_eq(
		soldier.animation_player.speed_scale,
		1.0,
		"Force-stopping an attack should also restore normal animation playback speed."
	)

func test_character_attack_speed_stat_defaults_to_one() -> void:
	var soldier = await _spawn_character(SoldierScene, true)

	assert_eq(
		soldier.get_attack_speed_multiplier(),
		1.0,
		"Character should resolve attack_speed_multiplier to 1.0 when no override is configured."
	)

func test_archer_projectile_release_uses_shared_windup() -> void:
	var archer = await _spawn_character(ArcherScene, true)

	archer.attack_module.start_attack(false)

	assert_false(archer.attack_module.damage_events.is_empty(), "Archer hard attack should queue a release event.")
	if archer.attack_module.damage_events.is_empty():
		return

	assert_almost_eq(
		float(archer.attack_module.damage_events[0]["trigger_time"]),
		WINDUP_SECONDS,
		WINDUP_EPSILON,
		"Projectile release should follow the shared 0.2s windup contract."
	)

func test_archer_light_projectile_release_uses_shared_windup() -> void:
	var archer = await _spawn_character(ArcherScene, true)

	archer.attack_module.start_attack(true)

	assert_false(archer.attack_module.damage_events.is_empty(), "Archer light attack should queue a release event.")
	if archer.attack_module.damage_events.is_empty():
		return

	assert_almost_eq(
		float(archer.attack_module.damage_events[0]["trigger_time"]),
		WINDUP_SECONDS,
		WINDUP_EPSILON,
		"Archer light release should follow the shared 0.2s windup contract."
	)

func test_swordsman_first_hits_use_shared_windup() -> void:
	var swordsman = await _spawn_character(SwordsmanScene, true)

	swordsman.attack_module._start_light_attack()

	assert_false(swordsman.attack_module.damage_events.is_empty(), "Swordsman light attack should queue damage.")
	if swordsman.attack_module.damage_events.is_empty():
		return

	assert_almost_eq(
		float(swordsman.attack_module.damage_events[0]["trigger_time"]),
		WINDUP_SECONDS,
		WINDUP_EPSILON,
		"Swordsman light attack should start from the shared 0.2s windup."
	)

	swordsman.attack_module.force_stop()
	swordsman.attack_module.set_attack_cooldown(0.0)
	swordsman.attack_module._start_hard_segment(1)

	assert_false(swordsman.attack_module.damage_events.is_empty(), "Swordsman heavy combo opener should queue damage.")
	if swordsman.attack_module.damage_events.is_empty():
		return

	assert_almost_eq(
		float(swordsman.attack_module.damage_events[0]["trigger_time"]),
		WINDUP_SECONDS,
		WINDUP_EPSILON,
		"Swordsman heavy combo opener should start from the shared 0.2s windup."
	)

	swordsman.attack_module.force_stop()
	swordsman.attack_module.set_attack_cooldown(0.0)
	swordsman.attack_module._start_ultimate_attack()

	assert_false(swordsman.attack_module.damage_events.is_empty(), "Swordsman ultimate attack should queue damage.")
	if swordsman.attack_module.damage_events.is_empty():
		return

	assert_almost_eq(
		float(swordsman.attack_module.damage_events[0]["trigger_time"]),
		WINDUP_SECONDS,
		WINDUP_EPSILON,
		"Swordsman ultimate opener should start from the shared 0.2s windup."
	)

func test_swordsman_combo_wait_freezes_animation_between_segments() -> void:
	var swordsman = await _spawn_character(SwordsmanScene, true)
	var speed_applied := _apply_attack_speed_multiplier(swordsman, 2.0)

	assert_true(
		speed_applied,
		"Swordsman timing regression needs a configurable attack_speed_multiplier state."
	)
	if not speed_applied:
		return

	swordsman.attack_module._start_hard_segment(1)

	assert_eq(
		swordsman.animation_player.speed_scale,
		2.0,
		"Active swordsman heavy playback should scale with attack_speed_multiplier."
	)

	swordsman.attack_module.update(0.5, null, false)

	assert_true(swordsman.attack_module.hard_waiting_next, "First heavy segment should enter combo wait after finishing.")
	assert_eq(
		swordsman.animation_player.speed_scale,
		0.0,
		"Heavy combo wait should still freeze the animation player."
	)

func test_ai_swordsman_heavy_combo_auto_chains_all_segments() -> void:
	var swordsman = await _spawn_character(SwordsmanScene, false)

	swordsman.attack_module._start_hard_segment(1)
	swordsman.attack_module.update(0.5, null, false)

	assert_eq(
		swordsman.attack_module.hard_combo_step,
		2,
		"AI swordsman heavy combo should advance into segment 2 after the opener finishes."
	)
	assert_true(
		swordsman.attack_module.is_attacking(),
		"AI swordsman should still be attacking while segment 2 auto-chains."
	)
	assert_eq(
		swordsman.attack_module.current_attack,
		"hard_attack",
		"AI swordsman should immediately restart hard_attack playback for segment 2."
	)

	swordsman.attack_module.update(0.4, null, false)

	assert_eq(
		swordsman.attack_module.hard_combo_step,
		3,
		"AI swordsman heavy combo should advance into segment 3 after segment 2 finishes."
	)
	assert_true(
		swordsman.attack_module.is_attacking(),
		"AI swordsman should still be attacking while segment 3 auto-chains."
	)
	assert_eq(
		swordsman.attack_module.current_attack,
		"hard_attack",
		"AI swordsman should immediately restart hard_attack playback for segment 3."
	)

	swordsman.attack_module.update(0.6, null, false)

	assert_false(
		swordsman.attack_module.is_attacking(),
		"AI swordsman heavy combo should fully finish after segment 3."
	)
	assert_eq(
		swordsman.attack_module.hard_combo_step,
		0,
		"AI swordsman heavy combo should clear combo state after the final segment."
	)

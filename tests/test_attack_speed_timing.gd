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

func test_swordsman_combo_wait_freezes_animation_between_segments() -> void:
	var swordsman = await _spawn_character(SwordsmanScene, true)

	swordsman.attack_module._start_hard_segment(1)
	swordsman.attack_module.update(0.5, null, false)

	assert_true(swordsman.attack_module.hard_waiting_next, "First heavy segment should enter combo wait after finishing.")
	assert_eq(
		swordsman.animation_player.speed_scale,
		0.0,
		"Heavy combo wait should still freeze the animation player."
	)

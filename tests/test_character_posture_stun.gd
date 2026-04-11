extends GutTest

const SwordsmanScene := preload("res://Character/Swordsman/swordsman.tscn")


func before_each() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false


func after_each() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false


func test_max_posture_applies_stunned_and_recovers_after_three_seconds() -> void:
	var character = add_child_autofree(SwordsmanScene.instantiate())
	await get_tree().process_frame

	character.add_posture(character.max_posture)

	assert_true(
		character.buff_controller != null and character.buff_controller.has_buff(&"stunned"),
		"Reaching max posture should apply the stunned buff."
	)
	assert_eq(character.get("is_stunned"), true, "Reaching max posture should mark the character as stunned.")
	assert_eq(character.is_action_locked(), true, "Stunned characters should be action locked.")
	assert_false(
		character.animation_tree == null or character.animation_tree.active,
		"Stunned characters should disable the animation tree and hold on the hurt pose."
	)

	await get_tree().create_timer(3.1, true, false, true).timeout
	await get_tree().process_frame
	await get_tree().process_frame

	assert_false(
		character.buff_controller != null and character.buff_controller.has_buff(&"stunned"),
		"Stunned should expire after 3 seconds."
	)
	assert_eq(character.get("is_stunned"), false, "Characters should leave the stunned state once the buff expires.")
	assert_eq(character.is_action_locked(), false, "Characters should recover control once stunned expires.")

extends GutTest

const TestScene := preload("res://Scenes/test.tscn")
const CHARACTER_NAMES := [&"Soldier", &"Swordsman", &"Orc", &"Archer", &"Slime"]


func test_test_scene_sets_all_clash_posture_ratios_to_one() -> void:
	var scene = add_child_autofree(TestScene.instantiate())
	await get_tree().process_frame

	for character_name in CHARACTER_NAMES:
		var character = scene.get_node(String(character_name))
		assert_not_null(character.attack_module, "%s should initialize its attack module in the test scene." % String(character_name))
		assert_true(
			character.attack_module.get("clash_attacker_posture_ratio") == 1.0,
			"%s should fill the attacker's posture on a single clash." % String(character_name)
		)
		assert_true(
			character.attack_module.get("clash_defender_posture_ratio") == 1.0,
			"%s should fill the defender's posture on a single clash." % String(character_name)
		)

extends Node2D

const CHARACTER_NAMES := [&"Soldier", &"Swordsman", &"Orc", &"Archer", &"Slime"]


func _ready() -> void:
	await get_tree().process_frame
	for character_name in CHARACTER_NAMES:
		var character := get_node_or_null(String(character_name))
		if character == null:
			continue
		var attack_module = character.get("attack_module")
		if attack_module == null:
			continue
		attack_module.set("clash_attacker_posture_ratio", 1.0)
		attack_module.set("clash_defender_posture_ratio", 1.0)

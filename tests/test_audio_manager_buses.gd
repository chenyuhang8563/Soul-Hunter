extends GutTest

const AudioManagerScript := preload("res://Global/audio_manager.gd")

var _manager: Node


func before_each() -> void:
	_manager = AudioManagerScript.new()
	add_child_autofree(_manager)
	_manager._ready()


func test_battle_sounds_route_to_sfx_bus() -> void:
	assert_eq(_manager._get_sound_bus("sword_swing"), &"SFX")
	assert_eq(_manager._get_sound_bus("sword_clash"), &"SFX")
	assert_eq(_manager._get_sound_bus("hit_flesh"), &"SFX")


func test_bgm_and_sfx_volume_linear_controls_audio_buses() -> void:
	_manager.set_bgm_volume_linear(0.5)
	_manager.set_sfx_volume_linear(0.25)

	assert_almost_eq(_manager.get_bgm_volume_linear(), 0.5, 0.01)
	assert_almost_eq(_manager.get_sfx_volume_linear(), 0.25, 0.01)

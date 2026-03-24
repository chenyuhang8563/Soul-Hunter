extends Node

var sounds = {
	"sword_clash": preload("res://Assets/SFX/sword-clash.wav"),
	"sword_swing": preload("res://Assets/SFX/swosh-sword-swing.wav")
}

func play_sfx_2d(sound_name: String, position: Vector2, pitch_scale: float = 1.0, volume_db: float = 0.0) -> AudioStreamPlayer2D:
	if not sounds.has(sound_name):
		push_warning("Sound not found: " + sound_name)
		return null
		
	var player = AudioStreamPlayer2D.new()
	player.stream = sounds[sound_name]
	player.global_position = position
	player.pitch_scale = pitch_scale
	player.volume_db = volume_db
	
	if sound_name == "sword_swing":
		player.bus = "SFX_Swing"
	else:
		player.bus = "SFX"
		
	var tree = get_tree()
	if tree and tree.current_scene:
		tree.current_scene.add_child(player)
	else:
		add_child(player)
		
	player.play()
	player.finished.connect(player.queue_free)
	return player

func play_sfx(sound_name: String, pitch_scale: float = 1.0, volume_db: float = 0.0) -> AudioStreamPlayer:
	if not sounds.has(sound_name):
		push_warning("Sound not found: " + sound_name)
		return null
		
	var player = AudioStreamPlayer.new()
	player.stream = sounds[sound_name]
	player.pitch_scale = pitch_scale
	player.volume_db = volume_db
	
	if sound_name == "sword_swing":
		player.bus = "SFX_Swing"
	else:
		player.bus = "SFX"
		
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	return player

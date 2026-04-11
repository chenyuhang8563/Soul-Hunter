extends Node

const SwordClashStream := preload("res://Assets/SFX/sword-clash.wav")
const SwordSwingStream := preload("res://Assets/SFX/swosh-sword-swing.wav")
const HitFleshStream := preload("res://Assets/SFX/hit_flesh.wav")
const AUDIO_MANAGER_GROUP := &"audio_manager_service"

@export var sword_clash_volume_db := 0.0
@export var sword_swing_volume_db := 0.0
@export var hit_flesh_volume_db := 0.0

func _enter_tree() -> void:
	add_to_group(AUDIO_MANAGER_GROUP)

func _resolve_volume_db(default_volume_db: float, volume_db_override = null) -> float:
	if volume_db_override == null:
		return default_volume_db
	return float(volume_db_override)

func _get_sound_stream(sound_name: String) -> AudioStream:
	match sound_name:
		"sword_clash":
			return SwordClashStream
		"sword_swing":
			return SwordSwingStream
		"hit_flesh":
			return HitFleshStream
		_:
			push_warning("Sound not found: " + sound_name)
			return null

func _get_sound_bus(sound_name: String) -> StringName:
	match sound_name:
		"sword_swing", "hit_flesh":
			return &"SFX_Battle"
		"sword_clash":
			return &"SFX_Battle"
		_:
			return &"SFX"

func _get_default_volume_db(sound_name: String) -> float:
	match sound_name:
		"sword_clash":
			return sword_clash_volume_db
		"sword_swing":
			return sword_swing_volume_db
		"hit_flesh":
			return hit_flesh_volume_db
		_:
			return 0.0

func play_sfx_2d(sound_name: String, position: Vector2, pitch_scale: float = 1.0, volume_db_override = null) -> AudioStreamPlayer2D:
	var stream := _get_sound_stream(sound_name)
	if stream == null:
		return null
		
	var player = AudioStreamPlayer2D.new()
	player.stream = stream
	player.global_position = position
	player.pitch_scale = pitch_scale
	player.volume_db = _resolve_volume_db(_get_default_volume_db(sound_name), volume_db_override)
	player.bus = _get_sound_bus(sound_name)
		
	var tree = get_tree()
	if tree and tree.current_scene:
		tree.current_scene.add_child(player)
	else:
		add_child(player)
		
	player.play()
	player.finished.connect(player.queue_free)
	return player

func play_sfx(sound_name: String, pitch_scale: float = 1.0, volume_db_override = null) -> AudioStreamPlayer:
	var stream := _get_sound_stream(sound_name)
	if stream == null:
		return null
		
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.volume_db = _resolve_volume_db(_get_default_volume_db(sound_name), volume_db_override)
	player.bus = _get_sound_bus(sound_name)
		
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	return player

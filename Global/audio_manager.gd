extends Node

const SwordClashStream := preload("res://Assets/SFX/sword-clash.wav")
const SwordSwingStream := preload("res://Assets/SFX/swosh-sword-swing.wav")
const HitFleshStream := preload("res://Assets/SFX/hit_flesh.wav")
const DefaultBgmStream := preload("res://Assets/SFX/battle.wav")
const AUDIO_MANAGER_GROUP := &"audio_manager_service"
const BGM_BUS := &"BGM"
const SFX_BUS := &"SFX"
const BGM_LOW_PASS_CUTOFF_HZ := 900.0
const BGM_LOW_PASS_RESONANCE := 0.8
const MIN_VOLUME_DB := -80.0

@export var sword_clash_volume_db := 0.0
@export var sword_swing_volume_db := 0.0
@export var hit_flesh_volume_db := 0.0
@export var bgm_volume_db := 0.0
@export var bgm_pause_blur_volume_db := -7.0

var _bgm_player: AudioStreamPlayer = null
var _bgm_bus_index := -1
var _sfx_bus_index := -1
var _bgm_low_pass_effect_index := -1
var _bgm_pause_blur_enabled := false

func _enter_tree() -> void:
	add_to_group(AUDIO_MANAGER_GROUP)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_bgm_bus()
	_setup_sfx_bus()
	_setup_bgm_player()
	play_default_bgm()
	set_bgm_pause_blur(false)

func _resolve_volume_db(default_volume_db: float, volume_db_override = null) -> float:
	if volume_db_override == null:
		return default_volume_db
	return float(volume_db_override)

func _setup_bgm_player() -> void:
	if _bgm_player != null:
		return

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.bus = BGM_BUS
	_bgm_player.volume_db = 0.0
	_bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_bgm_player)

func _setup_bgm_bus() -> void:
	_bgm_bus_index = _ensure_bus(BGM_BUS)

	_bgm_low_pass_effect_index = _find_bgm_low_pass_effect_index(_bgm_bus_index)
	if _bgm_low_pass_effect_index == -1:
		var low_pass_effect := AudioEffectLowPassFilter.new()
		low_pass_effect.cutoff_hz = BGM_LOW_PASS_CUTOFF_HZ
		low_pass_effect.resonance = BGM_LOW_PASS_RESONANCE
		AudioServer.add_bus_effect(_bgm_bus_index, low_pass_effect, 0)
		_bgm_low_pass_effect_index = 0

	AudioServer.set_bus_volume_db(_bgm_bus_index, bgm_volume_db)
	AudioServer.set_bus_effect_enabled(_bgm_bus_index, _bgm_low_pass_effect_index, false)

func _setup_sfx_bus() -> void:
	_sfx_bus_index = _ensure_bus(SFX_BUS)

func _ensure_bus(bus_name: StringName) -> int:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, bus_name)
		AudioServer.set_bus_send(bus_index, &"Master")
	return bus_index

func _find_bgm_low_pass_effect_index(bus_index: int) -> int:
	var effect_count := AudioServer.get_bus_effect_count(bus_index)
	for effect_index in effect_count:
		if AudioServer.get_bus_effect(bus_index, effect_index) is AudioEffectLowPassFilter:
			return effect_index
	return -1

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
		"sword_swing", "hit_flesh", "sword_clash":
			return SFX_BUS
		_:
			return SFX_BUS

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

func play_default_bgm() -> void:
	play_bgm_stream(DefaultBgmStream)

func play_bgm_stream(stream: AudioStream) -> void:
	if stream == null:
		return

	_setup_bgm_bus()
	_setup_bgm_player()

	var should_restart := _bgm_player.stream != stream or not _bgm_player.playing
	_bgm_player.stream = stream
	_bgm_player.bus = BGM_BUS
	_bgm_player.stream_paused = false
	if should_restart:
		_bgm_player.play()

func set_bgm_pause_blur(enabled: bool) -> void:
	_setup_bgm_bus()
	_bgm_pause_blur_enabled = enabled
	AudioServer.set_bus_effect_enabled(_bgm_bus_index, _bgm_low_pass_effect_index, enabled)
	AudioServer.set_bus_volume_db(_bgm_bus_index, bgm_pause_blur_volume_db if enabled else bgm_volume_db)

func set_bus_volume_linear(bus_name: StringName, value: float) -> void:
	var bus_index := _ensure_bus(bus_name)
	var clamped_value := clampf(value, 0.0, 1.0)
	var volume_db := MIN_VOLUME_DB if clamped_value <= 0.0 else linear_to_db(clamped_value)
	AudioServer.set_bus_volume_db(bus_index, volume_db)

func get_bus_volume_linear(bus_name: StringName) -> float:
	var bus_index := _ensure_bus(bus_name)
	var volume_db := AudioServer.get_bus_volume_db(bus_index)
	if volume_db <= MIN_VOLUME_DB:
		return 0.0
	return db_to_linear(volume_db)

func set_bgm_volume_linear(value: float) -> void:
	var clamped_value := clampf(value, 0.0, 1.0)
	bgm_volume_db = MIN_VOLUME_DB if clamped_value <= 0.0 else linear_to_db(clamped_value)
	if _bgm_pause_blur_enabled:
		return
	set_bus_volume_linear(BGM_BUS, clamped_value)

func get_bgm_volume_linear() -> float:
	if _bgm_pause_blur_enabled:
		if bgm_volume_db <= MIN_VOLUME_DB:
			return 0.0
		return db_to_linear(bgm_volume_db)
	return get_bus_volume_linear(BGM_BUS)

func set_sfx_volume_linear(value: float) -> void:
	set_bus_volume_linear(SFX_BUS, value)

func get_sfx_volume_linear() -> float:
	return get_bus_volume_linear(SFX_BUS)

func is_bgm_playing() -> bool:
	return _bgm_player != null and _bgm_player.playing

func get_current_bgm_stream() -> AudioStream:
	if _bgm_player == null:
		return null
	return _bgm_player.stream

func get_bgm_bus_name() -> StringName:
	return BGM_BUS

func get_bgm_low_pass_effect_index() -> int:
	return _bgm_low_pass_effect_index

func is_bgm_pause_blur_enabled() -> bool:
	return _bgm_pause_blur_enabled

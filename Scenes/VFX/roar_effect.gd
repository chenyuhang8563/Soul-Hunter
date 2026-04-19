extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _release_cb: Callable = Callable()
var _play_serial := 0


func _ready() -> void:
	reset_state()


func play_once(world_position: Vector2, facing_left: bool, release_cb: Callable) -> void:
	reset_state()
	_release_cb = release_cb
	_play_serial += 1
	var play_serial := _play_serial
	global_position = world_position
	visible = true
	if sprite != null:
		sprite.flip_h = facing_left
		sprite.frame = 0
	var playback_duration := _get_playback_duration()
	if animation_player != null and animation_player.has_animation(&"default"):
		animation_player.play(&"default")
	var tree := get_tree()
	if tree == null:
		_finish_playback(play_serial)
		return
	var release_timer := tree.create_timer(playback_duration, true, false, true)
	release_timer.timeout.connect(func():
		_finish_playback(play_serial)
	)


func reset_state() -> void:
	_play_serial += 1
	visible = false
	position = Vector2.ZERO
	if animation_player != null:
		animation_player.stop()
		if animation_player.has_animation(&"default"):
			animation_player.seek(0.0, true)
	if sprite != null:
		sprite.frame = 0
		sprite.flip_h = false
	_release_cb = Callable()


func _finish_playback(play_serial: int) -> void:
	if play_serial != _play_serial:
		return
	var release_cb := _release_cb
	visible = false
	_release_cb = Callable()
	if release_cb.is_valid():
		release_cb.call()


func _get_playback_duration() -> float:
	if animation_player != null and animation_player.has_animation(&"default"):
		return maxf(animation_player.get_animation(&"default").length, 0.01)
	return 0.3

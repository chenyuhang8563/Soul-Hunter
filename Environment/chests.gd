extends AnimatedSprite2D

signal chest_opened
signal loot_spawned(loot: Node)

const HintIconScene := preload("res://Scenes/icon.tscn")
const E_IconTexture := preload("res://Assets/Sprites/UI/E.png")
const KeyScene := preload("res://Environment/scenes_key.tscn")

var prompt_icon: Node2D
var is_opened := false
var interaction_range := 40.0
var _current_interactor: CharacterBody2D = null

func _ready() -> void:
	add_to_group("interaction_target")
	stop()
	frame = 0

func can_interact(interactor: CharacterBody2D) -> bool:
	if is_opened or not is_instance_valid(interactor):
		return false
	return global_position.distance_to(interactor.global_position) <= interaction_range

func interact(interactor: CharacterBody2D) -> void:
	if not can_interact(interactor):
		return
	_current_interactor = interactor
	open_chest()

func set_interaction_prompt_visible(show_prompt: bool) -> void:
	if show_prompt:
		if prompt_icon == null:
			prompt_icon = HintIconScene.instantiate() as Node2D
			var sprite = prompt_icon as Sprite2D
			if sprite == null:
				sprite = prompt_icon.get_node_or_null("Sprite2D")
			if sprite != null:
				sprite.texture = E_IconTexture
			add_child(prompt_icon)
		prompt_icon.position = Vector2(-8, -12)
	else:
		_clear_prompt_icon()

func _clear_prompt_icon() -> void:
	if prompt_icon != null and is_instance_valid(prompt_icon):
		prompt_icon.queue_free()
	prompt_icon = null

func open_chest() -> void:
	if is_opened:
		return
	is_opened = true
	_clear_prompt_icon()
	if sprite_frames and sprite_frames.has_animation("open"):
		sprite_frames.set_animation_loop("open", false)
	play("open")
	await animation_finished
	var key_instance = KeyScene.instantiate()
	get_parent().add_child(key_instance)
	if key_instance.has_method("jump_out"):
		key_instance.jump_out(global_position)
	else:
		key_instance.global_position = global_position
	chest_opened.emit()
	loot_spawned.emit(key_instance)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(queue_free)

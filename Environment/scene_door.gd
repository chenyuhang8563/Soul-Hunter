extends StaticBody2D

signal door_opened

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_opening := false
var is_opened := false

func _ready() -> void:
	add_to_group("interaction_target")
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("open"):
		animated_sprite.sprite_frames.set_animation_loop("open", false)
	animated_sprite.play("lock")
	animated_sprite.animation_finished.connect(_on_animation_finished)

func can_interact(_interactor: CharacterBody2D) -> bool:
	return false

func interact(_interactor: CharacterBody2D) -> void:
	pass

func set_interaction_prompt_visible(_visible: bool) -> void:
	pass

func open_door() -> void:
	if is_opening or is_opened:
		return
	is_opening = true
	animated_sprite.play("open")

func _on_animation_finished() -> void:
	if animated_sprite.animation != "open" or is_opened:
		return
	is_opening = false
	is_opened = true
	collision_shape.set_deferred("disabled", true)
	door_opened.emit()

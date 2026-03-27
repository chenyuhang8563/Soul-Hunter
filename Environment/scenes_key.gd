extends AnimatedSprite2D

signal key_collected

const HintIconScene := preload("res://Scenes/icon.tscn")
const E_IconTexture := preload("res://Assets/Sprites/UI/E.png")

var pickup_range := 30.0
var can_pick_up := false
var is_collected := false
var prompt_icon: Node2D
var pickup_area: Area2D

func _ready() -> void:
	add_to_group("level_key")
	add_to_group("interaction_target")
	play("default")
	_setup_pickup_area()

func _setup_pickup_area() -> void:
	pickup_area = Area2D.new()
	pickup_area.name = "PickupArea"
	pickup_area.monitoring = true
	add_child(pickup_area)
	var collision_shape := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = pickup_range
	collision_shape.shape = shape
	pickup_area.add_child(collision_shape)
	pickup_area.body_entered.connect(_on_pickup_body_entered)

func jump_out(start_pos: Vector2) -> void:
	global_position = start_pos
	var jump_height := 20.0
	var jump_distance := randf_range(-20.0, 20.0)
	var tween = create_tween()
	tween.tween_property(self, "global_position:y", start_pos.y - jump_height, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "global_position:x", start_pos.x + jump_distance / 2.0, 0.25).set_trans(Tween.TRANS_LINEAR)
	tween.chain().tween_property(self, "global_position:y", start_pos.y + 10.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "global_position:x", start_pos.x + jump_distance, 0.25).set_trans(Tween.TRANS_LINEAR)
	await tween.finished
	can_pick_up = true
	for body in pickup_area.get_overlapping_bodies():
		if body is CharacterBody2D and body.is_in_group("player_controlled"):
			interact(body)
			break

func can_interact(interactor: CharacterBody2D) -> bool:
	if not can_pick_up or is_collected or not is_instance_valid(interactor):
		return false
	return global_position.distance_to(interactor.global_position) <= pickup_range

func interact(interactor: CharacterBody2D) -> void:
	if can_interact(interactor):
		pick_up()

func set_interaction_prompt_visible(show_prompt: bool) -> void:
	if show_prompt and can_pick_up and not is_collected:
		if prompt_icon == null:
			prompt_icon = HintIconScene.instantiate() as Node2D
			var sprite = prompt_icon as Sprite2D
			if sprite == null:
				sprite = prompt_icon.get_node_or_null("Sprite2D")
			if sprite != null:
				sprite.texture = E_IconTexture
			add_child(prompt_icon)
		prompt_icon.position = Vector2(0, -12)
	else:
		_clear_prompt_icon()

func pick_up() -> void:
	if is_collected:
		return
	is_collected = true
	can_pick_up = false
	_clear_prompt_icon()
	key_collected.emit()
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

func _on_pickup_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player_controlled"):
		interact(body)

func _clear_prompt_icon() -> void:
	if prompt_icon != null and is_instance_valid(prompt_icon):
		prompt_icon.queue_free()
	prompt_icon = null

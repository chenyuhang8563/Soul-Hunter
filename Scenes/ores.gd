extends StaticBody2D

var hp := 3

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var original_position: Vector2
var shake_tween: Tween

func _ready() -> void:
	original_position = sprite.position

func apply_damage(amount: float, source: Node2D = null) -> void:
	# Check if the source is Swordsman
	var is_swordsman = false
	if source != null:
		var s_name = source.name.to_lower()
		var s_path = source.scene_file_path.to_lower() if "scene_file_path" in source else ""
		if s_name.find("swordsman") >= 0 or s_path.find("swordsman") >= 0:
			is_swordsman = true
			
	if not is_swordsman:
		return
		
	hp -= 1
	
	if hp > 0:
		_play_shake_animation()
	else:
		_destroy()

func _play_shake_animation() -> void:
	if shake_tween and shake_tween.is_valid():
		shake_tween.kill()
		
	sprite.position = original_position
	shake_tween = create_tween()
	
	var shake_amount = 2.0
	
	# Create a random shake effect (up, down, left, right)
	for i in range(4):
		var offset = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		shake_tween.tween_property(sprite, "position", original_position + offset, 0.05)
		
	shake_tween.tween_property(sprite, "position", original_position, 0.05)

func _destroy() -> void:
	# Disable collision immediately
	collision_shape.set_deferred("disabled", true)
	
	# Stop shaking if any
	if shake_tween and shake_tween.is_valid():
		shake_tween.kill()
	sprite.position = original_position
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

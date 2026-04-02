extends StaticBody2D

var hp := 3
var is_falling := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var fall_area: Area2D

func _ready() -> void:
	# Add an Area2D to detect collision with the ground/entities when falling
	fall_area = Area2D.new()
	var area_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	# The collision shape is about 8x104, so we make the fall area slightly larger to easily detect ground
	rect.size = Vector2(16, 110)
	area_shape.shape = rect
	area_shape.position = collision_shape.position
	fall_area.add_child(area_shape)
	add_child(fall_area)
	
	fall_area.monitoring = false
	fall_area.monitorable = false
	fall_area.body_entered.connect(_on_fall_body_entered)

func apply_damage(_amount: float, source: Node2D = null) -> void:
	if is_falling:
		return
		
	# Check if the source is Orc
	var is_orc = false
	if source != null:
		var s_name = source.name.to_lower()
		var s_path = source.scene_file_path.to_lower() if "scene_file_path" in source else ""
		if s_name.find("orc") >= 0 or s_path.find("orc") >= 0:
			is_orc = true
			
	if not is_orc:
		return
		
	hp -= 1
	
	var attack_dir = 1.0
	if source != null:
		attack_dir = sign(global_position.x - source.global_position.x)
		if attack_dir == 0:
			attack_dir = 1.0
			
	if hp > 0:
		_play_sway_animation(attack_dir)
	else:
		_fall(attack_dir)

var base_rotation := 0.0
var sway_tween: Tween

func _play_sway_animation(dir: float) -> void:
	if sway_tween and sway_tween.is_valid():
		sway_tween.kill()
		
	rotation = base_rotation
	sway_tween = create_tween()
	var sway_angle = 0.15 * dir
	
	sway_tween.tween_property(self, "rotation", base_rotation + sway_angle, 0.05)
	sway_tween.tween_property(self, "rotation", base_rotation - sway_angle * 0.5, 0.05)
	sway_tween.tween_property(self, "rotation", base_rotation, 0.05)

func _fall(dir: float) -> void:
	if sway_tween and sway_tween.is_valid():
		sway_tween.kill()
	rotation = base_rotation
	is_falling = true
	
	# Disable the main collision so characters can walk past it
	collision_shape.set_deferred("disabled", true)
	
	# Enable fall area to detect when it hits the ground
	fall_area.set_deferred("monitoring", true)
	
	var tween = create_tween()
	var target_rot = rotation + (PI / 2.0) * dir
	
	# Make it fall
	tween.tween_property(self, "rotation", target_rot, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

func _on_fall_body_entered(body: Node2D) -> void:
	if not is_falling or body == self:
		return
		
	# Ignore the Orc who chopped it, to prevent fading before hitting the ground
	if body.name.to_lower().find("orc") >= 0:
		return
		
	# When it hits an entity (like TileMapLayer or other bodies)
	fall_area.set_deferred("monitoring", false)
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(queue_free)

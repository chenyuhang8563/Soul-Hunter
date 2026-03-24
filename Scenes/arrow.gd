extends Area2D

@export var speed: float = 400.0
@export var damage: float = 10.0
@export var max_distance: float = 500.0

var direction: Vector2 = Vector2.RIGHT
var shooter: CharacterBody2D
var distance_traveled: float = 0.0

func setup(new_direction: Vector2, new_damage: float, new_shooter: CharacterBody2D) -> void:
	direction = new_direction.normalized()
	damage = new_damage
	shooter = new_shooter
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	var movement = speed * delta
	position += direction * movement
	distance_traveled += movement
	
	if distance_traveled >= max_distance:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body == shooter:
		return
		
	if body is CharacterBody2D:
		if _is_valid_target(body):
			if body.has_method("apply_damage"):
				body.apply_damage(damage, shooter)
			queue_free()
	elif body is TileMap or body is StaticBody2D:
		queue_free()

func _is_valid_target(target: CharacterBody2D) -> bool:
	if not target.has_method("is_alive") or not target.is_alive():
		return false
	
	# Check team if applicable
	if shooter != null and shooter.has_method("get_team_id") and target.has_method("get_team_id"):
		if shooter.get_team_id() == target.get_team_id():
			return false
			
	return true

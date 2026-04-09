extends Area2D

const INCOMING_DAMAGE_IS_CRITICAL_META := "incoming_damage_is_critical"

@export var speed: float = 400.0
@export var damage: float = 10.0
@export var max_distance: float = 500.0

var direction: Vector2 = Vector2.RIGHT
var shooter: CharacterBody2D
var distance_traveled: float = 0.0
var developer_mode_powered := false
var critical_hit := false

func setup(new_direction: Vector2, new_damage: float, new_shooter: CharacterBody2D, new_critical_hit: bool = false) -> void:
	direction = new_direction.normalized()
	damage = new_damage
	shooter = new_shooter
	developer_mode_powered = DeveloperMode.applies_to(new_shooter)
	critical_hit = new_critical_hit
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
					var final_damage := _get_effective_damage(body)
					var had_critical_meta := body.has_meta(INCOMING_DAMAGE_IS_CRITICAL_META)
					var previous_critical_meta = null
					if had_critical_meta:
						previous_critical_meta = body.get_meta(INCOMING_DAMAGE_IS_CRITICAL_META)
					body.set_meta(INCOMING_DAMAGE_IS_CRITICAL_META, critical_hit)
					if shooter != null:
						shooter.set_meta("damage_is_ranged", true)
					body.apply_damage(final_damage, shooter)
					if shooter != null and shooter.has_signal("damage_dealt"):
						shooter.emit_signal("damage_dealt", body, final_damage)
					if shooter != null:
						shooter.remove_meta("damage_is_ranged")
					if had_critical_meta:
						body.set_meta(INCOMING_DAMAGE_IS_CRITICAL_META, previous_critical_meta)
					else:
						body.remove_meta(INCOMING_DAMAGE_IS_CRITICAL_META)
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

func _get_effective_damage(target: CharacterBody2D) -> float:
	if developer_mode_powered and _is_enemy_character_target(target):
		return _get_lethal_damage(target)
	return damage

func _is_enemy_character_target(target: CharacterBody2D) -> bool:
	if shooter == null:
		return false
	if not shooter.has_method("get_team_id") or not target.has_method("get_team_id"):
		return false
	return int(shooter.get_team_id()) != int(target.get_team_id())

func _get_lethal_damage(target: CharacterBody2D) -> float:
	var target_health = target.get("health")
	if target_health != null and target_health.get("current_health") != null:
		return maxf(9999.0, float(target_health.current_health) + 1.0)
	return 9999.0

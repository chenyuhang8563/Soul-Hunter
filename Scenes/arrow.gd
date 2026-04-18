extends Area2D

const INCOMING_DAMAGE_IS_CRITICAL_META := "incoming_damage_is_critical"
const FlameShader := preload("res://Shaders/explosive_arrow_flame.gdshader")
const ExplosionScene := preload("res://Scenes/VFX/explosion.tscn")
const VFX_POOL_PATH := "/root/VfxPool"

@export var speed: float = 400.0
@export var damage: float = 10.0
@export var max_distance: float = 500.0

var direction: Vector2 = Vector2.RIGHT
var shooter: CharacterBody2D
var distance_traveled: float = 0.0
var developer_mode_powered := false
var critical_hit := false
var is_explosive := false
var explosion_damage := 0.0
var explosion_radius := 0.0

var _has_exploded := false

func setup(
		new_direction: Vector2,
		new_damage: float,
		new_shooter: CharacterBody2D,
		new_critical_hit: bool = false,
		projectile_config: Dictionary = {}
) -> void:
	direction = new_direction.normalized()
	damage = new_damage
	shooter = new_shooter
	developer_mode_powered = DeveloperMode.applies_to(new_shooter)
	critical_hit = new_critical_hit
	_apply_projectile_config(projectile_config)
	rotation = direction.angle()
	_apply_visual_state()

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
			if is_explosive:
				_explode(body.global_position, body)
			else:
				_apply_hit_damage(body, damage, critical_hit)
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

func _apply_projectile_config(projectile_config: Dictionary) -> void:
	is_explosive = bool(projectile_config.get("explosive", false))
	explosion_damage = maxf(0.0, float(projectile_config.get("explosion_damage", 0.0)))
	explosion_radius = maxf(0.0, float(projectile_config.get("explosion_radius", 0.0)))
	_has_exploded = false

func _apply_visual_state() -> void:
	var sprite := _get_arrow_sprite()
	if sprite == null:
		return
	if not is_explosive:
		sprite.material = null
		return
	var material := ShaderMaterial.new()
	material.shader = FlameShader
	material.set_shader_parameter("flame_enabled", true)
	sprite.material = material

func _get_arrow_sprite() -> Sprite2D:
	return get_node_or_null("Sprite2D") as Sprite2D

func _explode(world_position: Vector2, direct_hit_target: CharacterBody2D = null) -> void:
	if _has_exploded:
		return
	_has_exploded = true
	_play_explosion_vfx(world_position)
	for target in _find_explosion_targets(world_position, direct_hit_target):
		_apply_hit_damage(target, explosion_damage, false)
	queue_free()

func _find_explosion_targets(world_position: Vector2, direct_hit_target: CharacterBody2D = null) -> Array[CharacterBody2D]:
	var targets: Array[CharacterBody2D] = []
	var seen_target_ids: Dictionary = {}
	if direct_hit_target != null and is_instance_valid(direct_hit_target):
		if _is_valid_target(direct_hit_target):
			targets.append(direct_hit_target)
			seen_target_ids[direct_hit_target.get_instance_id()] = true

	if explosion_radius <= 0.0 or not is_inside_tree():
		return targets

	var shape := CircleShape2D.new()
	shape.radius = explosion_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, world_position)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if shooter != null and is_instance_valid(shooter):
		query.exclude = [shooter]
	var results := get_world_2d().direct_space_state.intersect_shape(query, 32)
	for result: Dictionary in results:
		var collider: Object = result.get("collider")
		if not (collider is CharacterBody2D):
			continue
		var candidate := collider as CharacterBody2D
		if not _is_valid_target(candidate):
			continue
		var candidate_id := candidate.get_instance_id()
		if seen_target_ids.has(candidate_id):
			continue
		seen_target_ids[candidate_id] = true
		targets.append(candidate)
	return targets

func _apply_hit_damage(target: CharacterBody2D, base_damage: float, should_mark_critical: bool) -> void:
	if target == null or not is_instance_valid(target) or not target.has_method("apply_damage"):
		return
	var final_damage := base_damage
	if not is_explosive or should_mark_critical:
		final_damage = _get_effective_damage(target)
	elif developer_mode_powered and _is_enemy_character_target(target):
		final_damage = _get_lethal_damage(target)

	var had_critical_meta := target.has_meta(INCOMING_DAMAGE_IS_CRITICAL_META)
	var previous_critical_meta = null
	if had_critical_meta:
		previous_critical_meta = target.get_meta(INCOMING_DAMAGE_IS_CRITICAL_META)
	target.set_meta(INCOMING_DAMAGE_IS_CRITICAL_META, should_mark_critical)
	if shooter != null:
		shooter.set_meta("damage_is_ranged", true)
	target.apply_damage(final_damage, shooter)
	if shooter != null and shooter.has_signal("damage_dealt"):
		shooter.emit_signal("damage_dealt", target, final_damage)
	if shooter != null:
		shooter.remove_meta("damage_is_ranged")
	if had_critical_meta:
		target.set_meta(INCOMING_DAMAGE_IS_CRITICAL_META, previous_critical_meta)
	else:
		target.remove_meta(INCOMING_DAMAGE_IS_CRITICAL_META)

func _play_explosion_vfx(world_position: Vector2) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var vfx_pool := tree.root.get_node_or_null(VFX_POOL_PATH)
	if vfx_pool != null and vfx_pool.has_method("play_explosion"):
		vfx_pool.call("play_explosion", world_position)
		return
	var current_scene := tree.current_scene
	if current_scene == null:
		return
	var effect := ExplosionScene.instantiate() as AnimatedSprite2D
	if effect == null:
		return
	current_scene.add_child(effect)
	effect.global_position = world_position
	effect.animation_finished.connect(effect.queue_free, CONNECT_ONE_SHOT)
	effect.play(&"default")

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

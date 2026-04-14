extends Node

const ROOT_NAME := "WorldVfxRoot"
const CUT_Z_INDEX := 10
const PARTICLE_EFFECT_META := "_vfx_pool_particle_effect"
const PARTICLE_BASE_PROCESS_MATERIAL_META := "_vfx_pool_base_process_material"
const PARTICLE_BASE_DIRECTION_META := "_vfx_pool_base_direction"
const PARTICLE_PLAY_SERIAL_META := "_vfx_pool_play_serial"

const CutScene := preload("res://Scenes/VFX/cut.tscn")
const AfterimageScene := preload("res://Scenes/VFX/afterimage.tscn")
const ExplosionScene := preload("res://Scenes/VFX/explosion.tscn")

var _scene_root: Node2D = null
var _registry: Dictionary = {}
var _available: Dictionary = {}
var _active: Dictionary = {}


func _ready() -> void:
	_registry = _build_default_registry()
	_available = {}
	_active = {}
	for key in _registry.keys():
		_available[key] = []
		_active[key] = []


func _build_default_registry() -> Dictionary:
	return {
		"cut": {"scene": CutScene, "prewarm": 8},
		"afterimage": {"scene": AfterimageScene, "prewarm": 15},
		"explosion": {"scene": ExplosionScene, "prewarm": 6},
		"hurt_particles": {"scene": null, "template_name": "HurtParticles", "prewarm": 4},
		"parry_particles": {"scene": null, "template_name": "ParryParticles", "prewarm": 4},
		"finisher_burst": {"scene": null, "template_name": "FinisherBurstParticles", "prewarm": 2},
		"finisher_slash": {"scene": null, "template_name": "FinisherSlashParticles", "prewarm": 2},
	}


func _ensure_scene_root() -> Node2D:
	var tree := get_tree()
	if tree == null:
		return null
	var current_scene := tree.current_scene
	if current_scene == null:
		return null

	var can_reuse_root := _scene_root != null and is_instance_valid(_scene_root) and _scene_root.get_parent() == current_scene
	if can_reuse_root:
		return _scene_root

	var existing_root := current_scene.get_node_or_null(ROOT_NAME) as Node2D
	if existing_root != null:
		_scene_root = existing_root
		return _scene_root

	_scene_root = Node2D.new()
	_scene_root.name = ROOT_NAME
	current_scene.add_child(_scene_root)
	return _scene_root


func play_cut(source: Node2D, spec: Dictionary, _attack_range: float) -> void:
	if source == null or not is_instance_valid(source):
		return
	var effect := _acquire_scene_effect(&"cut")
	if effect == null:
		return
	effect.z_as_relative = false
	effect.z_index = CUT_Z_INDEX
	var active_for_key: Array = _active[&"cut"]
	active_for_key.append(effect)
	var release_cb := Callable(self, "_release_effect").bind(&"cut", effect)
	effect.call("play_once", _get_model_edge_anchor(source), _is_facing_left(source), spec.duplicate(true), release_cb)


func play_afterimage(request: Dictionary) -> void:
	var effect := _acquire_scene_effect(&"afterimage")
	if effect == null:
		return
	var active_for_key: Array = _active[&"afterimage"]
	active_for_key.append(effect)
	var release_cb := Callable(self, "_release_effect").bind(&"afterimage", effect)
	effect.call(
		"initialize",
		request.get("texture"),
		int(request.get("hframes", 1)),
		int(request.get("vframes", 1)),
		int(request.get("frame", 0)),
		request.get("transform", Transform2D.IDENTITY),
		bool(request.get("flip_h", false)),
		request.get("offset", Vector2.ZERO),
		bool(request.get("centered", true)),
		request.get("color", Color(1, 1, 1, 0.7)),
		float(request.get("duration", 0.4)),
		float(request.get("final_scale", 0.8)),
		release_cb
	)


func play_explosion(world_position: Vector2) -> void:
	var effect_node := _acquire_scene_effect(&"explosion")
	if effect_node == null:
		return
	var effect := effect_node as AnimatedSprite2D
	if effect == null:
		_release_effect(&"explosion", effect_node)
		return
	effect.global_position = world_position
	effect.visible = true
	effect.animation = &"default"
	var active_for_key: Array = _active[&"explosion"]
	active_for_key.append(effect)
	var release_cb := Callable(self, "_on_explosion_animation_finished").bind(effect)
	if effect.animation_finished.is_connected(release_cb):
		effect.animation_finished.disconnect(release_cb)
	effect.animation_finished.connect(
		release_cb,
		CONNECT_ONE_SHOT
	)
	effect.play(&"default")


func play_particle_template(
		effect_key: StringName,
		source_node: Node,
		world_position: Vector2,
		horizontal_direction: float = 0.0
) -> void:
	if source_node == null or not is_instance_valid(source_node):
		return
	var template := _find_particle_template(effect_key, source_node)
	if template == null:
		return
	var effect_node := _acquire_particle_effect(effect_key, template)
	if effect_node == null:
		return
	var effect := effect_node as Node2D
	if effect == null:
		_release_effect(effect_key, effect_node)
		return
	_restore_particle_effect(effect)
	effect.global_position = world_position
	effect.visible = true
	_configure_particle_direction_recursive(effect, horizontal_direction)
	var active_for_key: Array = _active[effect_key]
	active_for_key.append(effect)
	var cleanup_delay := _restart_particles_recursive(effect)
	_schedule_particle_release(effect_key, effect, cleanup_delay)


func _on_explosion_animation_finished(effect: AnimatedSprite2D) -> void:
	_release_effect(&"explosion", effect)


func _acquire_scene_effect(effect_key: StringName) -> Node:
	var root := _ensure_scene_root()
	if root == null:
		return null
	if not _registry.has(effect_key):
		return null
	if not _available.has(effect_key):
		_available[effect_key] = []
	if not _active.has(effect_key):
		_active[effect_key] = []
	_prune_effect_list(effect_key, _available)
	_prune_effect_list(effect_key, _active)
	var available_for_key: Array = _available[effect_key]
	if available_for_key.is_empty():
		var entry: Dictionary = _registry[effect_key]
		var prewarm_count := int(entry.get("prewarm", 1))
		_prewarm_scene_effect(effect_key, maxi(prewarm_count, 1))
	if available_for_key.is_empty():
		return null
	var effect := available_for_key.pop_back() as Node
	if effect == null or not is_instance_valid(effect):
		return null
	if effect.get_parent() != root:
		if effect.get_parent() != null:
			effect.reparent(root)
		else:
			root.add_child(effect)
	return effect


func _prewarm_scene_effect(effect_key: StringName, count: int) -> void:
	if count <= 0 or not _registry.has(effect_key):
		return
	var root := _ensure_scene_root()
	if root == null:
		return
	var entry: Dictionary = _registry[effect_key]
	var packed_scene = entry.get("scene")
	if not (packed_scene is PackedScene):
		return
	if not _available.has(effect_key):
		_available[effect_key] = []
	var available_for_key: Array = _available[effect_key]
	for i in count:
		var effect := (packed_scene as PackedScene).instantiate()
		if effect == null:
			continue
		root.add_child(effect)
		if effect.has_method("reset_state"):
			effect.call("reset_state")
		else:
			effect.visible = false
		available_for_key.append(effect)


func _find_particle_template(effect_key: StringName, source_node: Node) -> Node:
	if not _registry.has(effect_key):
		return null
	var entry: Dictionary = _registry[effect_key]
	var template_name := String(entry.get("template_name", ""))
	if template_name == "":
		return null
	var template := source_node.find_child(template_name, true, false)
	if template == null:
		push_warning("%s node not found on %s" % [template_name, source_node.name])
	return template


func _acquire_particle_effect(effect_key: StringName, template: Node) -> Node2D:
	if template == null or not (template is Node2D):
		return null
	var root := _ensure_scene_root()
	if root == null or not _registry.has(effect_key):
		return null
	if not _available.has(effect_key):
		_available[effect_key] = []
	if not _active.has(effect_key):
		_active[effect_key] = []
	_prune_effect_list(effect_key, _available)
	_prune_effect_list(effect_key, _active)
	var available_for_key: Array = _available[effect_key]
	if available_for_key.is_empty():
		var entry: Dictionary = _registry[effect_key]
		var prewarm_count := int(entry.get("prewarm", 1))
		_prewarm_particle_effect(effect_key, template, maxi(prewarm_count, 1))
	if available_for_key.is_empty():
		return null
	var effect := available_for_key.pop_back() as Node2D
	if effect == null or not is_instance_valid(effect):
		return null
	if effect.get_parent() != root:
		if effect.get_parent() != null:
			effect.reparent(root)
		else:
			root.add_child(effect)
	return effect


func _prewarm_particle_effect(effect_key: StringName, template: Node, count: int) -> void:
	if count <= 0 or template == null or not (template is Node2D):
		return
	var root := _ensure_scene_root()
	if root == null:
		return
	if not _available.has(effect_key):
		_available[effect_key] = []
	var available_for_key: Array = _available[effect_key]
	for i in count:
		var effect := template.duplicate()
		if not (effect is Node2D):
			continue
		var effect_node := effect as Node2D
		effect_node.set_meta(PARTICLE_EFFECT_META, true)
		root.add_child(effect_node)
		_capture_particle_defaults_recursive(effect_node)
		_reset_particle_effect(effect_node)
		available_for_key.append(effect_node)


func _release_effect(effect_key: StringName, effect: Node) -> void:
	if effect == null or not is_instance_valid(effect):
		return
	if not _active.has(effect_key):
		_active[effect_key] = []
	if not _available.has(effect_key):
		_available[effect_key] = []
	var active_for_key: Array = _active[effect_key]
	active_for_key.erase(effect)
	if effect_key == &"explosion" and effect is AnimatedSprite2D:
		var animated := effect as AnimatedSprite2D
		animated.stop()
		animated.frame = 0
	if bool(effect.get_meta(PARTICLE_EFFECT_META, false)) and effect is Node2D:
		_reset_particle_effect(effect as Node2D)
	elif effect.has_method("reset_state"):
		effect.call("reset_state")
	else:
		effect.visible = false
	var root := _ensure_scene_root()
	if root != null and effect.get_parent() != root:
		if effect.get_parent() != null:
			effect.reparent(root)
		else:
			root.add_child(effect)
	var available_for_key: Array = _available[effect_key]
	if not available_for_key.has(effect):
		available_for_key.append(effect)


func _capture_particle_defaults_recursive(node: Node) -> void:
	if node is GPUParticles2D:
		var gpu_particles := node as GPUParticles2D
		var process_material := gpu_particles.process_material
		if process_material is Resource:
			gpu_particles.set_meta(PARTICLE_BASE_PROCESS_MATERIAL_META, (process_material as Resource).duplicate(true))
		else:
			gpu_particles.remove_meta(PARTICLE_BASE_PROCESS_MATERIAL_META)
	elif node is CPUParticles2D:
		var cpu_particles := node as CPUParticles2D
		cpu_particles.set_meta(PARTICLE_BASE_DIRECTION_META, cpu_particles.direction)
	for child in node.get_children():
		_capture_particle_defaults_recursive(child)


func _reset_particle_effect(effect: Node2D) -> void:
	_restore_particle_effect(effect)
	effect.visible = false


func _restore_particle_effect(node: Node) -> void:
	if node is GPUParticles2D:
		var gpu_particles := node as GPUParticles2D
		gpu_particles.emitting = false
		var base_process_material = gpu_particles.get_meta(PARTICLE_BASE_PROCESS_MATERIAL_META, null)
		if base_process_material == null:
			gpu_particles.process_material = null
		elif base_process_material is Resource:
			gpu_particles.process_material = (base_process_material as Resource).duplicate(true)
	elif node is CPUParticles2D:
		var cpu_particles := node as CPUParticles2D
		cpu_particles.emitting = false
		if cpu_particles.has_meta(PARTICLE_BASE_DIRECTION_META):
			cpu_particles.direction = cpu_particles.get_meta(PARTICLE_BASE_DIRECTION_META)
	for child in node.get_children():
		_restore_particle_effect(child)


func _schedule_particle_release(effect_key: StringName, effect: Node2D, cleanup_delay: float) -> void:
	var tree := get_tree()
	if tree == null:
		_release_effect(effect_key, effect)
		return
	var play_serial := int(effect.get_meta(PARTICLE_PLAY_SERIAL_META, 0)) + 1
	effect.set_meta(PARTICLE_PLAY_SERIAL_META, play_serial)
	var release_timer := tree.create_timer(cleanup_delay, true, false, true)
	release_timer.timeout.connect(func():
		if effect == null or not is_instance_valid(effect):
			return
		if int(effect.get_meta(PARTICLE_PLAY_SERIAL_META, 0)) != play_serial:
			return
		_release_effect(effect_key, effect)
	)


func _prune_effect_list(effect_key: StringName, bucket: Dictionary) -> void:
	if not bucket.has(effect_key):
		bucket[effect_key] = []
	var next_items: Array = []
	for effect in bucket[effect_key]:
		if effect != null and is_instance_valid(effect):
			next_items.append(effect)
	bucket[effect_key] = next_items


func _restart_particles_recursive(node: Node) -> float:
	var cleanup_delay := 1.0
	if node is GPUParticles2D:
		var gpu_particles := node as GPUParticles2D
		gpu_particles.emitting = false
		gpu_particles.restart()
		gpu_particles.emitting = true
		cleanup_delay = maxf(cleanup_delay, gpu_particles.lifetime + 0.2)
	elif node is CPUParticles2D:
		var cpu_particles := node as CPUParticles2D
		cpu_particles.emitting = false
		cpu_particles.restart()
		cpu_particles.emitting = true
		cleanup_delay = maxf(cleanup_delay, cpu_particles.lifetime + 0.2)
	for child in node.get_children():
		cleanup_delay = maxf(cleanup_delay, _restart_particles_recursive(child))
	return cleanup_delay


func _configure_particle_direction_recursive(node: Node, horizontal_direction: float) -> void:
	if node is Node2D:
		_configure_particle_direction(node as Node2D, horizontal_direction)
	for child in node.get_children():
		_configure_particle_direction_recursive(child, horizontal_direction)


func _configure_particle_direction(particle_node: Node2D, horizontal_direction: float) -> void:
	if is_zero_approx(horizontal_direction):
		return
	if particle_node is GPUParticles2D:
		var gpu_particles := particle_node as GPUParticles2D
		var process_material := gpu_particles.process_material
		if process_material is ParticleProcessMaterial:
			var duplicated_material := (process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
			var direction: Vector3 = duplicated_material.direction
			var x_magnitude := absf(direction.x)
			if is_zero_approx(x_magnitude):
				x_magnitude = 1.0
			direction.x = x_magnitude * horizontal_direction
			duplicated_material.direction = direction
			gpu_particles.process_material = duplicated_material
	elif particle_node is CPUParticles2D:
		var cpu_particles := particle_node as CPUParticles2D
		var direction_2d: Vector2 = cpu_particles.direction
		var x_magnitude_2d := absf(direction_2d.x)
		if is_zero_approx(x_magnitude_2d):
			x_magnitude_2d = 1.0
		direction_2d.x = x_magnitude_2d * horizontal_direction
		cpu_particles.direction = direction_2d


func _is_facing_left(source: Node2D) -> bool:
	var sprite := _find_sprite(source)
	return sprite != null and sprite.flip_h


func _get_model_edge_anchor(source: Node2D) -> Vector2:
	var sprite := _find_sprite(source)
	if sprite == null:
		return source.global_position
	var rect := sprite.get_rect()
	var anchor_local_x := rect.position.x + rect.size.x * 0.5
	var anchor_local_y := rect.position.y + rect.size.y * 0.5
	return sprite.to_global(Vector2(anchor_local_x, anchor_local_y))


func _find_sprite(source: Node2D) -> Sprite2D:
	if source == null:
		return null
	if source.has_method("get"):
		var sprite_prop = source.get("sprite")
		if sprite_prop is Sprite2D:
			return sprite_prop as Sprite2D
	var named_sprite := source.get_node_or_null("Sprite2D") as Sprite2D
	if named_sprite != null:
		return named_sprite
	named_sprite = source.get_node_or_null("Soldier") as Sprite2D
	if named_sprite != null:
		return named_sprite
	for child in source.get_children():
		if child is Sprite2D:
			return child as Sprite2D
	return null

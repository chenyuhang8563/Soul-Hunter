extends GutTest

const VFX_POOL_SCRIPT_PATH := "res://Global/vfx_pool.gd"
const ATTACK_MODULE_BASE_SCRIPT_PATH := "res://Character/Common/attack_module_base.gd"


class FakeParticlePool:
	extends Node

	var call_count := 0
	var calls: Array[Dictionary] = []
	var last_effect_key: StringName = &""
	var last_source_node: Node = null
	var last_world_position := Vector2.ZERO
	var last_horizontal_direction := 0.0
	var duration_call_count := 0
	var duration_calls: Array[StringName] = []
	var effect_durations: Dictionary = {}

	func play_particle_effect(effect_key: StringName, world_position: Vector2, horizontal_direction: float = 0.0) -> void:
		call_count += 1
		calls.append({
			"effect_key": effect_key,
			"world_position": world_position,
			"horizontal_direction": horizontal_direction,
		})
		last_effect_key = effect_key
		last_world_position = world_position
		last_horizontal_direction = horizontal_direction

	func get_effect_duration(effect_key: StringName) -> float:
		duration_call_count += 1
		duration_calls.append(effect_key)
		return float(effect_durations.get(effect_key, 0.0))


class FakeDamageTarget:
	extends Node2D

	var total_damage := 0.0
	var last_damage_source: Node = null

	func apply_damage(amount: float, source: Node) -> void:
		total_damage += amount
		last_damage_source = source


func test_play_particle_effect_reuses_pooled_scene_instance_and_resets_direction() -> void:
	var tree := get_tree()
	var previous_scene: Node = tree.current_scene
	var scene := Node2D.new()
	scene.name = "TempVfxParticleScene"
	tree.root.add_child(scene)
	tree.current_scene = scene

	var pool: Node = add_child_autofree(_new_vfx_pool())
	pool.play_particle_effect(&"hurt_particles", Vector2(12.0, 18.0), -1.0)

	assert_eq(pool._active[&"hurt_particles"].size(), 1, "Hurt particle effect should be tracked as active after playback")
	var first_effect := pool._active[&"hurt_particles"][0] as GPUParticles2D
	assert_ne(first_effect, null, "Pooled hurt particle effect should use a GPUParticles2D instance")
	assert_eq(first_effect.amount, 20, "Scene-backed hurt particles should come from the registered hurt particle scene")
	assert_eq(first_effect.lifetime, 0.5, "Scene-backed hurt particles should preserve the hurt scene lifetime")
	assert_eq(first_effect.global_position, Vector2(12.0, 18.0), "Pooled hurt particles should use the requested world position")
	assert_true(first_effect.emitting, "Pooled hurt particles should restart emission when played")

	var first_material := first_effect.process_material as ParticleProcessMaterial
	assert_ne(first_material, null, "Pooled hurt particles should preserve a process material")
	assert_eq(first_material.direction.x, -1.0, "Playback should flip particle direction to match the requested horizontal direction")

	await tree.create_timer(1.05).timeout

	assert_eq(pool._active[&"hurt_particles"].size(), 0, "Finished hurt particles should be removed from the active pool")
	assert_eq(pool._available[&"hurt_particles"].size(), 4, "Finished hurt particles should return to the prewarmed pool")

	pool.play_particle_effect(&"hurt_particles", Vector2(-6.0, 5.0), 1.0)

	assert_eq(pool._active[&"hurt_particles"].size(), 1, "Replayed hurt particles should be tracked as active")
	var second_effect := pool._active[&"hurt_particles"][0] as GPUParticles2D
	assert_eq(second_effect, first_effect, "Released hurt particles should reuse the pooled instance on the next play")
	assert_eq(second_effect.global_position, Vector2(-6.0, 5.0), "Reused hurt particles should update to the new world position")

	var second_material := second_effect.process_material as ParticleProcessMaterial
	assert_ne(second_material, null, "Reused hurt particles should still have a process material")
	assert_eq(second_material.direction.x, 1.0, "Reused hurt particles should reset direction before applying the next play direction")

	tree.current_scene = previous_scene
	scene.queue_free()


func test_play_particle_effect_supports_nested_finisher_scenes() -> void:
	var tree := get_tree()
	var previous_scene: Node = tree.current_scene
	var scene := Node2D.new()
	scene.name = "TempVfxFinisherParticleScene"
	tree.root.add_child(scene)
	tree.current_scene = scene

	var pool: Node = add_child_autofree(_new_vfx_pool())
	pool.play_particle_effect(&"finisher_burst", Vector2(7.0, -3.0))

	assert_eq(pool._active[&"finisher_burst"].size(), 1, "Nested finisher burst should be tracked as active after playback")
	var effect_root := pool._active[&"finisher_burst"][0] as Node2D
	assert_ne(effect_root, null, "Nested finisher burst should duplicate its Node2D template root")
	assert_eq(effect_root.global_position, Vector2(7.0, -3.0), "Nested finisher burst should use the requested world position")

	var effect_burst := effect_root.get_node_or_null("Burst0") as GPUParticles2D
	assert_ne(effect_burst, null, "Nested finisher burst should preserve child particle nodes")
	assert_ne(effect_root.get_node_or_null("Burst315"), null, "Nested finisher burst should preserve the full registered child structure")
	assert_true(effect_burst.emitting, "Nested finisher burst child particles should restart emission")

	await tree.create_timer(1.05).timeout

	assert_eq(pool._active[&"finisher_burst"].size(), 0, "Finished finisher burst should be removed from the active pool")
	assert_eq(pool._available[&"finisher_burst"].size(), 2, "Finished finisher burst should return to the prewarmed pool")

	tree.current_scene = previous_scene
	scene.queue_free()


func test_play_particle_template_uses_registry_scene_without_source_template() -> void:
	var tree := get_tree()
	var previous_scene: Node = tree.current_scene
	var scene := Node2D.new()
	scene.name = "TempVfxParticleCompatScene"
	tree.root.add_child(scene)
	tree.current_scene = scene

	var source := Node2D.new()
	scene.add_child(source)

	var pool: Node = add_child_autofree(_new_vfx_pool())
	pool.play_particle_template(&"parry_particles", source, Vector2(8.0, 9.0), -1.0)

	assert_eq(pool._active[&"parry_particles"].size(), 1, "Legacy particle playback should no longer require a source template node")
	var effect := pool._active[&"parry_particles"][0] as GPUParticles2D
	assert_ne(effect, null, "Legacy particle playback should still create a pooled particle instance")
	assert_eq(effect.randomness, 1.0, "Legacy playback should use the registered parry particle scene")
	var effect_material := effect.process_material as ParticleProcessMaterial
	assert_ne(effect_material, null, "Legacy playback should preserve the particle process material")
	assert_eq(effect_material.spread, 180.0, "Legacy playback should preserve the registered parry particle spread")
	assert_eq(effect_material.direction.x, -1.0, "Legacy playback should still apply directional overrides to the scene-backed effect")

	tree.current_scene = previous_scene
	scene.queue_free()


func test_vfx_pool_reports_finisher_particle_duration_from_registry() -> void:
	var pool: Node = add_child_autofree(_new_vfx_pool())

	assert_eq(pool.get_effect_duration(&"hurt_particles"), 0.5, "Hurt particle duration should come from the registered particle scene lifetime")
	assert_eq(pool.get_effect_duration(&"parry_particles"), 0.3, "Parry particle duration should come from the registered particle scene lifetime")
	assert_eq(pool.get_effect_duration(&"finisher_burst"), 0.3, "Finisher burst duration should come from the nested registered particle scene lifetime")
	assert_eq(pool.get_effect_duration(&"finisher_slash"), 0.2, "Finisher slash duration should come from the registered particle scene lifetime")
	assert_eq(pool.get_effect_duration(&"missing_effect"), 0.0, "Unknown particle keys should report zero duration")


func test_attack_module_base_forwards_world_particles_without_source_template_lookup() -> void:
	var tree := get_tree()
	var previous_scene: Node = tree.current_scene
	var scene := Node2D.new()
	scene.name = "TempAttackModuleParticleScene"
	tree.root.add_child(scene)
	tree.current_scene = scene

	var existing_pool := tree.root.get_node_or_null("VfxPool")
	if existing_pool != null:
		tree.root.remove_child(existing_pool)

	var fake_pool := FakeParticlePool.new()
	fake_pool.name = "VfxPool"
	tree.root.add_child(fake_pool)

	var owner := CharacterBody2D.new()
	scene.add_child(owner)

	var module = _new_attack_module()
	module.owner = owner
	module._spawn_particles_from_template(owner, "ParryParticles", scene, Vector2(4.0, 9.0), -1.0)

	assert_eq(fake_pool.call_count, 1, "AttackModuleBase should route world-space particle playback through VfxPool")
	assert_eq(fake_pool.last_effect_key, &"parry_particles", "Particle forwarding should map the template name to the pool registry key")
	assert_eq(fake_pool.last_source_node, null, "Particle forwarding should not depend on passing a source template node")
	assert_eq(fake_pool.last_world_position, Vector2(4.0, 9.0), "Particle forwarding should preserve the requested world position")
	assert_eq(fake_pool.last_horizontal_direction, -1.0, "Particle forwarding should preserve the requested particle direction")

	tree.root.remove_child(fake_pool)
	fake_pool.queue_free()
	if existing_pool != null:
		tree.root.add_child(existing_pool)
	tree.current_scene = previous_scene
	scene.queue_free()


func test_attack_module_base_maps_finisher_particle_names_to_pool_keys() -> void:
	var tree := get_tree()
	var previous_scene: Node = tree.current_scene
	var scene := Node2D.new()
	scene.name = "TempAttackModuleFinisherParticleScene"
	tree.root.add_child(scene)
	tree.current_scene = scene

	var existing_pool := tree.root.get_node_or_null("VfxPool")
	if existing_pool != null:
		tree.root.remove_child(existing_pool)

	var fake_pool := FakeParticlePool.new()
	fake_pool.name = "VfxPool"
	tree.root.add_child(fake_pool)

	var owner := CharacterBody2D.new()
	scene.add_child(owner)

	var module = _new_attack_module()
	module.owner = owner
	module._spawn_particles_from_template(owner, "FinisherBurstParticles", scene, Vector2(10.0, 20.0))
	module._spawn_particles_from_template(owner, "FinisherSlashParticles", scene, Vector2(-3.0, 6.0))

	assert_eq(fake_pool.call_count, 2, "AttackModuleBase should forward both finisher particle requests to VfxPool")
	if fake_pool.call_count < 2:
		tree.root.remove_child(fake_pool)
		fake_pool.queue_free()
		if existing_pool != null:
			tree.root.add_child(existing_pool)
		tree.current_scene = previous_scene
		scene.queue_free()
		return
	assert_eq(fake_pool.calls[0].get("effect_key"), &"finisher_burst", "FinisherBurstParticles should map to the finisher_burst pool key")
	assert_eq(fake_pool.calls[1].get("effect_key"), &"finisher_slash", "FinisherSlashParticles should map to the finisher_slash pool key")

	tree.root.remove_child(fake_pool)
	fake_pool.queue_free()
	if existing_pool != null:
		tree.root.add_child(existing_pool)
	tree.current_scene = previous_scene
	scene.queue_free()


func test_attack_module_base_routes_hurt_particles_with_hit_direction() -> void:
	var tree := get_tree()
	var previous_scene: Node = tree.current_scene
	var scene := Node2D.new()
	scene.name = "TempAttackModuleHurtParticleScene"
	tree.root.add_child(scene)
	tree.current_scene = scene

	var existing_pool := tree.root.get_node_or_null("VfxPool")
	if existing_pool != null:
		tree.root.remove_child(existing_pool)

	var fake_pool := FakeParticlePool.new()
	fake_pool.name = "VfxPool"
	tree.root.add_child(fake_pool)

	var owner := CharacterBody2D.new()
	owner.position = Vector2(4.0, 0.0)
	scene.add_child(owner)

	var target := FakeDamageTarget.new()
	target.position = Vector2(18.0, 9.0)
	scene.add_child(target)

	var module = _new_attack_module()
	module.owner = owner

	assert_true(module._apply_damage_to_target(target, 5.0), "Damage application should succeed for a valid hurt-particle target")
	assert_eq(fake_pool.call_count, 1, "Hurt particle playback should route through VfxPool")
	assert_eq(fake_pool.last_effect_key, &"hurt_particles", "HurtParticles should map to the hurt_particles pool key")
	assert_eq(fake_pool.last_world_position, target.global_position, "Hurt particle playback should use the target world position")
	assert_eq(fake_pool.last_horizontal_direction, 1.0, "Hurt particle playback should preserve the computed hit direction")

	tree.root.remove_child(fake_pool)
	fake_pool.queue_free()
	if existing_pool != null:
		tree.root.add_child(existing_pool)
	tree.current_scene = previous_scene
	scene.queue_free()


func test_attack_module_base_gets_finisher_duration_from_vfx_pool() -> void:
	var tree := get_tree()
	var previous_scene: Node = tree.current_scene
	var scene := Node2D.new()
	scene.name = "TempAttackModuleFinisherDurationScene"
	tree.root.add_child(scene)
	tree.current_scene = scene

	var existing_pool := tree.root.get_node_or_null("VfxPool")
	if existing_pool != null:
		tree.root.remove_child(existing_pool)

	var fake_pool := FakeParticlePool.new()
	fake_pool.name = "VfxPool"
	fake_pool.effect_durations[&"finisher_burst"] = 0.6
	fake_pool.effect_durations[&"finisher_slash"] = 0.45
	tree.root.add_child(fake_pool)

	var owner := CharacterBody2D.new()
	scene.add_child(owner)

	var module = _new_attack_module()
	module.owner = owner

	assert_eq(fake_pool.duration_call_count, 0)
	assert_eq(module._get_finisher_effect_duration(), 0.6, "Finisher duration should come from VfxPool-owned particle timings")
	assert_eq(fake_pool.duration_call_count, 2, "AttackModuleBase should query both finisher particle durations from VfxPool")
	assert_eq(fake_pool.duration_calls, [&"finisher_burst", &"finisher_slash"])

	tree.root.remove_child(fake_pool)
	fake_pool.queue_free()
	if existing_pool != null:
		tree.root.add_child(existing_pool)
	tree.current_scene = previous_scene
	scene.queue_free()


func test_attack_module_base_finisher_duration_falls_back_without_vfx_pool() -> void:
	var tree := get_tree()
	var previous_scene: Node = tree.current_scene
	var scene := Node2D.new()
	scene.name = "TempAttackModuleFinisherFallbackScene"
	tree.root.add_child(scene)
	tree.current_scene = scene

	var existing_pool := tree.root.get_node_or_null("VfxPool")
	if existing_pool != null:
		tree.root.remove_child(existing_pool)
	assert_eq(tree.root.get_node_or_null("VfxPool"), null, "Fallback coverage must remove any root VfxPool before exercising the no-pool path")

	var owner := CharacterBody2D.new()
	scene.add_child(owner)

	var module = _new_attack_module()
	module.owner = owner

	assert_eq(module._get_finisher_effect_duration(), 0.3, "Finisher duration should keep the safe fallback when VfxPool is unavailable")

	if existing_pool != null:
		tree.root.add_child(existing_pool)
	tree.current_scene = previous_scene
	scene.queue_free()


func test_particle_template_scenes_exist_and_load() -> void:
	var hurt_scene := load("res://Scenes/VFX/particles/hurt_particles.tscn") as PackedScene
	var parry_scene := load("res://Scenes/VFX/particles/parry_particles.tscn") as PackedScene
	var finisher_burst_scene := load("res://Scenes/VFX/particles/finisher_burst_particles.tscn") as PackedScene
	var finisher_slash_scene := load("res://Scenes/VFX/particles/finisher_slash_particles.tscn") as PackedScene

	assert_ne(hurt_scene, null)
	assert_ne(parry_scene, null)
	assert_ne(finisher_burst_scene, null)
	assert_ne(finisher_slash_scene, null)
	if hurt_scene == null or parry_scene == null or finisher_burst_scene == null or finisher_slash_scene == null:
		return

	var hurt := add_child_autofree(hurt_scene.instantiate()) as GPUParticles2D
	assert_ne(hurt, null)
	assert_eq(hurt.name, "HurtParticles")
	assert_eq(hurt.amount, 20)
	assert_eq(hurt.lifetime, 0.5)
	assert_true(hurt.one_shot)
	assert_eq(hurt.explosiveness, 1.0)
	assert_ne(hurt.process_material as ParticleProcessMaterial, null)

	var parry := add_child_autofree(parry_scene.instantiate()) as GPUParticles2D
	assert_ne(parry, null)
	assert_eq(parry.name, "ParryParticles")
	assert_eq(parry.randomness, 1.0)
	var parry_material := parry.process_material as ParticleProcessMaterial
	assert_ne(parry_material, null)
	assert_eq(parry_material.spread, 180.0)

	var finisher_slash := add_child_autofree(finisher_slash_scene.instantiate()) as GPUParticles2D
	assert_ne(finisher_slash, null)
	assert_eq(finisher_slash.name, "FinisherSlashParticles")
	assert_ne(finisher_slash.texture, null)
	assert_eq(finisher_slash.lifetime, 0.2)
	assert_ne(finisher_slash.process_material as ParticleProcessMaterial, null)


func test_finisher_burst_scene_preserves_nested_particle_children() -> void:
	var scene := load("res://Scenes/VFX/particles/finisher_burst_particles.tscn") as PackedScene
	assert_ne(scene, null)
	if scene == null:
		return
	var root := add_child_autofree(scene.instantiate()) as Node2D
	assert_eq(root.name, "FinisherBurstParticles")
	assert_eq(root.get_child_count(), 8)

	assert_ne(root.get_node_or_null("Burst0"), null)
	assert_ne(root.get_node_or_null("Burst45"), null)
	assert_ne(root.get_node_or_null("Burst90"), null)
	assert_ne(root.get_node_or_null("Burst135"), null)
	assert_ne(root.get_node_or_null("Burst180"), null)
	assert_ne(root.get_node_or_null("Burst225"), null)
	assert_ne(root.get_node_or_null("Burst270"), null)
	assert_ne(root.get_node_or_null("Burst315"), null)

	var burst_90 := root.get_node_or_null("Burst90") as GPUParticles2D
	assert_ne(burst_90, null)
	if burst_90 == null:
		return
	assert_ne(burst_90.texture, null)
	assert_eq(burst_90.lifetime, 0.3)
	var burst_90_material := burst_90.process_material as ParticleProcessMaterial
	assert_ne(burst_90_material, null)
	if burst_90_material == null:
		return
	assert_eq(burst_90_material.direction, Vector3(0, 1, 0))


func test_character_template_no_longer_contains_world_particle_nodes() -> void:
	var scene := load("res://Character/Common/character_template.tscn") as PackedScene
	assert_ne(scene, null)
	if scene == null:
		return
	var instance: Node = add_child_autofree(scene.instantiate())

	assert_eq(instance.get_node_or_null("HurtParticles"), null)
	assert_eq(instance.get_node_or_null("ParryParticles"), null)
	assert_eq(instance.get_node_or_null("FinisherBurstParticles"), null)
	assert_eq(instance.get_node_or_null("FinisherSlashParticles"), null)


func _make_gpu_particle(name: String, lifetime: float, direction_x: float) -> GPUParticles2D:
	var particle := GPUParticles2D.new()
	particle.name = name
	particle.emitting = false
	particle.one_shot = true
	particle.lifetime = lifetime
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(direction_x, 0.0, 0.0)
	particle.process_material = material
	return particle


func _new_vfx_pool() -> Node:
	var pool_script := load(VFX_POOL_SCRIPT_PATH)
	assert_ne(pool_script, null, "VfxPool script should exist at %s" % VFX_POOL_SCRIPT_PATH)
	if pool_script == null:
		return Node.new()
	return pool_script.new()


func _new_attack_module():
	var module_script := load(ATTACK_MODULE_BASE_SCRIPT_PATH)
	assert_ne(module_script, null, "AttackModuleBase script should exist at %s" % ATTACK_MODULE_BASE_SCRIPT_PATH)
	if module_script == null:
		return null
	return module_script.new()

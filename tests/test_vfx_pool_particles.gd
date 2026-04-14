extends GutTest

const VFX_POOL_SCRIPT_PATH := "res://Global/vfx_pool.gd"
const ATTACK_MODULE_BASE_SCRIPT_PATH := "res://Character/Common/attack_module_base.gd"


class FakeParticlePool:
	extends Node

	var call_count := 0
	var last_effect_key: StringName = &""
	var last_source_node: Node = null
	var last_world_position := Vector2.ZERO
	var last_horizontal_direction := 0.0

	func play_particle_template(effect_key: StringName, source_node: Node, world_position: Vector2, horizontal_direction: float = 0.0) -> void:
		call_count += 1
		last_effect_key = effect_key
		last_source_node = source_node
		last_world_position = world_position
		last_horizontal_direction = horizontal_direction


func test_play_particle_template_reuses_pooled_instance_and_resets_direction() -> void:
	var tree := get_tree()
	var previous_scene: Node = tree.current_scene
	var scene := Node2D.new()
	scene.name = "TempVfxParticleScene"
	tree.root.add_child(scene)
	tree.current_scene = scene

	var source := Node2D.new()
	scene.add_child(source)
	var template := _make_gpu_particle("HurtParticles", 0.01, 2.5)
	source.add_child(template)

	var pool: Node = add_child_autofree(_new_vfx_pool())
	pool.play_particle_template(&"hurt_particles", source, Vector2(12.0, 18.0), -1.0)

	assert_eq(pool._active[&"hurt_particles"].size(), 1, "Hurt particle effect should be tracked as active after playback")
	var first_effect := pool._active[&"hurt_particles"][0] as GPUParticles2D
	assert_ne(first_effect, null, "Pooled hurt particle effect should use a GPUParticles2D instance")
	assert_eq(first_effect.global_position, Vector2(12.0, 18.0), "Pooled hurt particles should use the requested world position")
	assert_true(first_effect.emitting, "Pooled hurt particles should restart emission when played")

	var first_material := first_effect.process_material as ParticleProcessMaterial
	assert_ne(first_material, null, "Pooled hurt particles should preserve a process material")
	assert_eq(first_material.direction.x, -2.5, "Playback should flip particle direction to match the requested horizontal direction")

	var template_material := template.process_material as ParticleProcessMaterial
	assert_ne(template_material, null, "Template should keep its original process material")
	assert_eq(template_material.direction.x, 2.5, "Template process material should not be mutated by pooled playback")

	await tree.create_timer(1.05).timeout

	assert_eq(pool._active[&"hurt_particles"].size(), 0, "Finished hurt particles should be removed from the active pool")
	assert_eq(pool._available[&"hurt_particles"].size(), 4, "Finished hurt particles should return to the prewarmed pool")

	pool.play_particle_template(&"hurt_particles", source, Vector2(-6.0, 5.0), 1.0)

	assert_eq(pool._active[&"hurt_particles"].size(), 1, "Replayed hurt particles should be tracked as active")
	var second_effect := pool._active[&"hurt_particles"][0] as GPUParticles2D
	assert_eq(second_effect, first_effect, "Released hurt particles should reuse the pooled instance on the next play")
	assert_eq(second_effect.global_position, Vector2(-6.0, 5.0), "Reused hurt particles should update to the new world position")

	var second_material := second_effect.process_material as ParticleProcessMaterial
	assert_ne(second_material, null, "Reused hurt particles should still have a process material")
	assert_eq(second_material.direction.x, 2.5, "Reused hurt particles should reset direction before applying the next play direction")

	tree.current_scene = previous_scene
	scene.queue_free()


func test_play_particle_template_supports_nested_finisher_templates() -> void:
	var tree := get_tree()
	var previous_scene: Node = tree.current_scene
	var scene := Node2D.new()
	scene.name = "TempVfxFinisherParticleScene"
	tree.root.add_child(scene)
	tree.current_scene = scene

	var source := Node2D.new()
	scene.add_child(source)
	var template_root := Node2D.new()
	template_root.name = "FinisherBurstParticles"
	var burst := _make_gpu_particle("Burst0", 0.01, 1.0)
	template_root.add_child(burst)
	source.add_child(template_root)

	var pool: Node = add_child_autofree(_new_vfx_pool())
	pool.play_particle_template(&"finisher_burst", source, Vector2(7.0, -3.0))

	assert_eq(pool._active[&"finisher_burst"].size(), 1, "Nested finisher burst should be tracked as active after playback")
	var effect_root := pool._active[&"finisher_burst"][0] as Node2D
	assert_ne(effect_root, null, "Nested finisher burst should duplicate its Node2D template root")
	assert_eq(effect_root.global_position, Vector2(7.0, -3.0), "Nested finisher burst should use the requested world position")

	var effect_burst := effect_root.get_node_or_null("Burst0") as GPUParticles2D
	assert_ne(effect_burst, null, "Nested finisher burst should preserve child particle nodes")
	assert_true(effect_burst.emitting, "Nested finisher burst child particles should restart emission")

	await tree.create_timer(1.05).timeout

	assert_eq(pool._active[&"finisher_burst"].size(), 0, "Finished finisher burst should be removed from the active pool")
	assert_eq(pool._available[&"finisher_burst"].size(), 2, "Finished finisher burst should return to the prewarmed pool")

	tree.current_scene = previous_scene
	scene.queue_free()


func test_attack_module_base_forwards_world_particles_to_vfx_pool() -> void:
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
	var template := _make_gpu_particle("ParryParticles", 0.01, 1.0)
	owner.add_child(template)

	var module = _new_attack_module()
	module.owner = owner
	module._spawn_particles_from_template(owner, "ParryParticles", scene, Vector2(4.0, 9.0), -1.0)

	assert_eq(fake_pool.call_count, 1, "AttackModuleBase should route world-space particle playback through VfxPool")
	assert_eq(fake_pool.last_effect_key, &"parry_particles", "Particle forwarding should map the template name to the pool registry key")
	assert_eq(fake_pool.last_source_node, owner, "Particle forwarding should preserve the source node for template lookup")
	assert_eq(fake_pool.last_world_position, Vector2(4.0, 9.0), "Particle forwarding should preserve the requested world position")
	assert_eq(fake_pool.last_horizontal_direction, -1.0, "Particle forwarding should preserve the requested particle direction")

	tree.root.remove_child(fake_pool)
	fake_pool.queue_free()
	if existing_pool != null:
		tree.root.add_child(existing_pool)
	tree.current_scene = previous_scene
	scene.queue_free()


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

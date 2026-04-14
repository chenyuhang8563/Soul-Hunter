extends GutTest

const VFX_POOL_SCRIPT_PATH := "res://Global/vfx_pool.gd"
const MELEE_SLASH_MANAGER_SCRIPT_PATH := "res://Global/melee_slash_vfx_manager.gd"
const EXPECTED_REGISTRY_KEYS := [
	"cut",
	"afterimage",
	"explosion",
	"hurt_particles",
	"parry_particles",
	"finisher_burst",
	"finisher_slash",
]


class FakeCutEffect:
	extends Node2D

	var recorded_world_position := Vector2.ZERO
	var recorded_facing_left := false
	var recorded_spec: Dictionary = {}
	var recorded_release_cb: Callable = Callable()

	func play_once(world_position: Vector2, facing_left: bool, spec: Dictionary, release_cb: Callable) -> void:
		recorded_world_position = world_position
		recorded_facing_left = facing_left
		recorded_spec = spec.duplicate(true)
		recorded_release_cb = release_cb

	func trigger_release() -> void:
		if recorded_release_cb.is_valid():
			recorded_release_cb.call()


class FakeVfxPool:
	extends Node

	var call_count := 0
	var last_source: Node2D = null
	var last_spec: Dictionary = {}
	var last_attack_range := 0.0

	func play_cut(source: Node2D, spec: Dictionary, attack_range: float) -> void:
		call_count += 1
		last_source = source
		last_spec = spec.duplicate(true)
		last_attack_range = attack_range


func test_ensure_scene_root_creates_world_vfx_root_once() -> void:
	var tree := get_tree()
	var previous_scene: Node = tree.current_scene
	var scene := Node2D.new()
	scene.name = "TempVfxTestScene"
	tree.root.add_child(scene)
	tree.current_scene = scene

	var pool: Node = add_child_autofree(_new_vfx_pool())
	var first_root: Node = pool._ensure_scene_root()
	var second_root: Node = pool._ensure_scene_root()

	assert_ne(first_root, null, "_ensure_scene_root should return a node")
	assert_true(first_root is Node2D, "_ensure_scene_root should return Node2D")
	assert_eq(first_root.name, "WorldVfxRoot", "Root should use the expected name")
	assert_eq(first_root.get_parent(), scene, "Root should be parented to current scene")
	assert_eq(second_root, first_root, "Second ensure call should reuse existing root")

	tree.current_scene = previous_scene
	scene.queue_free()


func test_default_registry_contains_world_vfx_keys() -> void:
	var pool: Node = add_child_autofree(_new_vfx_pool())
	var registry_keys: Array = pool._build_default_registry().keys()

	for key in EXPECTED_REGISTRY_KEYS:
		assert_true(registry_keys.has(key), "Registry should include key: %s" % key)


func test_ensure_scene_root_reuses_existing_world_vfx_root_from_scene() -> void:
	var tree := get_tree()
	var previous_scene: Node = tree.current_scene
	var scene := Node2D.new()
	scene.name = "TempVfxExistingRootScene"
	tree.root.add_child(scene)
	tree.current_scene = scene

	var existing_root := Node2D.new()
	existing_root.name = "WorldVfxRoot"
	scene.add_child(existing_root)

	var pool: Node = add_child_autofree(_new_vfx_pool())
	var resolved_root: Node = pool._ensure_scene_root()

	assert_eq(resolved_root, existing_root, "Pool should reuse an existing WorldVfxRoot from the current scene")

	tree.current_scene = previous_scene
	scene.queue_free()


func test_play_cut_reuses_a_pooled_cut_instance() -> void:
	var tree := get_tree()
	var previous_scene: Node = tree.current_scene
	var scene := Node2D.new()
	scene.name = "TempVfxCutPoolScene"
	tree.root.add_child(scene)
	tree.current_scene = scene

	var source := Node2D.new()
	scene.add_child(source)
	var sprite := Sprite2D.new()
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	sprite.texture = ImageTexture.create_from_image(image)
	source.add_child(sprite)

	var pool: Node = add_child_autofree(_new_vfx_pool())
	pool.play_cut(source, {"duration": 0.1, "base_scale": Vector2.ONE}, 42.0)

	assert_eq(pool._active[&"cut"].size(), 1, "Cut effect should be tracked as active")

	var effect: Node = pool._active[&"cut"][0]
	pool._release_effect(&"cut", effect)

	assert_eq(pool._available[&"cut"].size(), 8, "Released cut should return to the prewarmed pool")
	assert_eq(pool._active[&"cut"].size(), 0, "Released cut should no longer be active")

	tree.current_scene = previous_scene
	scene.queue_free()


func test_play_cut_sets_layering_and_wires_play_once_and_release() -> void:
	var tree := get_tree()
	var previous_scene: Node = tree.current_scene
	var scene := Node2D.new()
	scene.name = "TempVfxCutArgsScene"
	tree.root.add_child(scene)
	tree.current_scene = scene

	var source := Node2D.new()
	source.global_position = Vector2(11.0, 19.0)
	scene.add_child(source)
	var sprite := Sprite2D.new()
	sprite.flip_h = true
	var image := Image.create(12, 6, false, Image.FORMAT_RGBA8)
	sprite.texture = ImageTexture.create_from_image(image)
	source.add_child(sprite)

	var packed := PackedScene.new()
	var template := FakeCutEffect.new()
	assert_eq(packed.pack(template), OK, "Packed scene for fake cut effect should pack successfully")
	template.queue_free()

	var pool: Node = add_child_autofree(_new_vfx_pool())
	pool._registry[&"cut"] = {"scene": packed, "prewarm": 1}
	pool._available[&"cut"] = []
	pool._active[&"cut"] = []

	var spec := {"duration": 0.2, "base_scale": Vector2(1.5, 1.5)}
	pool.play_cut(source, spec, 99.0)

	assert_eq(pool._active[&"cut"].size(), 1, "Fake cut effect should be active after play_cut")
	var effect := pool._active[&"cut"][0] as FakeCutEffect
	assert_ne(effect, null, "Active pooled cut should use the fake cut effect")
	assert_eq(effect.z_as_relative, false, "Cut effect layering should use absolute z ordering")
	assert_eq(effect.z_index, 10, "Cut effect should preserve legacy z-index")
	assert_eq(effect.recorded_world_position, pool._get_model_edge_anchor(source), "Cut anchor should match model edge anchor")
	assert_true(effect.recorded_facing_left, "Cut facing should follow source sprite flip_h")
	assert_eq(effect.recorded_spec, spec, "Cut playback should receive the spec dictionary")
	assert_true(effect.recorded_release_cb.is_valid(), "Cut playback should be wired with a release callback")

	effect.trigger_release()
	assert_eq(pool._active[&"cut"].size(), 0, "Release callback should move effect out of active list")
	assert_eq(pool._available[&"cut"].size(), 1, "Release callback should return effect to available pool")

	tree.current_scene = previous_scene
	scene.queue_free()


func test_melee_slash_manager_forwards_to_vfx_pool_cut() -> void:
	var tree := get_tree()
	var fake_pool := FakeVfxPool.new()
	fake_pool.name = "VfxPool"
	var existing_pool := tree.root.get_node_or_null("VfxPool")
	if existing_pool != null:
		tree.root.remove_child(existing_pool)
	tree.root.add_child(fake_pool)

	var manager_script := load(MELEE_SLASH_MANAGER_SCRIPT_PATH)
	assert_ne(manager_script, null, "Melee slash manager script should exist at %s" % MELEE_SLASH_MANAGER_SCRIPT_PATH)
	var manager: Node = manager_script.new()
	add_child_autofree(manager)

	var source := Node2D.new()
	var spec := {"duration": 0.1, "base_scale": Vector2.ONE}
	manager.play_slash(source, spec, 42.0)

	assert_eq(fake_pool.call_count, 1, "Compatibility shim should forward slash playback to VfxPool")
	assert_eq(fake_pool.last_source, source, "Forwarded source should match caller input")
	assert_eq(fake_pool.last_spec, spec, "Forwarded spec should match caller input")
	assert_eq(fake_pool.last_attack_range, 42.0, "Forwarded attack range should match caller input")

	tree.root.remove_child(fake_pool)
	fake_pool.queue_free()
	source.queue_free()
	if existing_pool != null:
		tree.root.add_child(existing_pool)


func _new_vfx_pool() -> Node:
	var pool_script := load(VFX_POOL_SCRIPT_PATH)
	assert_ne(pool_script, null, "VfxPool script should exist at %s" % VFX_POOL_SCRIPT_PATH)
	if pool_script == null:
		return Node.new()
	return pool_script.new()

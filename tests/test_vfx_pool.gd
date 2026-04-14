extends GutTest

const VFX_POOL_SCRIPT_PATH := "res://Global/vfx_pool.gd"
const EXPECTED_REGISTRY_KEYS := [
	"cut",
	"afterimage",
	"explosion",
	"hurt_particles",
	"parry_particles",
	"finisher_burst",
	"finisher_slash",
]


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


func _new_vfx_pool() -> Node:
	var pool_script := load(VFX_POOL_SCRIPT_PATH)
	assert_ne(pool_script, null, "VfxPool script should exist at %s" % VFX_POOL_SCRIPT_PATH)
	if pool_script == null:
		return Node.new()
	return pool_script.new()

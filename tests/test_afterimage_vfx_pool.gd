extends GutTest

const VFX_POOL_SCRIPT_PATH := "res://Global/vfx_pool.gd"


func test_play_afterimage_returns_effect_to_pool_after_finish() -> void:
	var tree := get_tree()
	var previous_scene: Node = tree.current_scene
	var scene := Node2D.new()
	scene.name = "TempVfxAfterimageScene"
	tree.root.add_child(scene)
	tree.current_scene = scene

	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	var texture := ImageTexture.create_from_image(image)
	var request := {
		"texture": texture,
		"hframes": 1,
		"vframes": 1,
		"frame": 0,
		"transform": Transform2D.IDENTITY,
		"flip_h": false,
		"offset": Vector2.ZERO,
		"centered": true,
		"color": Color(1, 1, 1, 0.7),
		"duration": 0.01,
		"final_scale": 0.8,
	}

	var pool: Node = add_child_autofree(_new_vfx_pool())
	pool.play_afterimage(request)

	assert_eq(pool._active[&"afterimage"].size(), 1, "Afterimage should be tracked as active")

	var effect := pool._active[&"afterimage"][0] as Afterimage
	assert_ne(effect, null, "Pooled afterimage should use Afterimage scene instances")

	effect._on_fade_out_finished()

	assert_eq(pool._active[&"afterimage"].size(), 0, "Finished afterimage should be removed from active list")
	assert_eq(pool._available[&"afterimage"].size(), 15, "Finished afterimage should return to prewarmed pool")

	tree.current_scene = previous_scene
	scene.queue_free()


func _new_vfx_pool() -> Node:
	var pool_script := load(VFX_POOL_SCRIPT_PATH)
	assert_ne(pool_script, null, "VfxPool script should exist at %s" % VFX_POOL_SCRIPT_PATH)
	if pool_script == null:
		return Node.new()
	return pool_script.new()

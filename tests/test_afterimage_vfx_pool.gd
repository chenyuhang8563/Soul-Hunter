extends GutTest

const VFX_POOL_SCRIPT_PATH := "res://Global/vfx_pool.gd"

class FakeVfxPool:
	extends Node

	var call_count := 0
	var last_request: Dictionary = {}

	func play_afterimage(request: Dictionary) -> void:
		call_count += 1
		last_request = request.duplicate(true)


class CharacterAfterimageProbe:
	extends "res://Character/Common/character.gd"

	func _ready() -> void:
		pass


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

	await tree.create_timer(0.05).timeout

	assert_eq(pool._active[&"afterimage"].size(), 0, "Finished afterimage should be removed from active list")
	assert_eq(pool._available[&"afterimage"].size(), 15, "Finished afterimage should return to prewarmed pool")

	tree.current_scene = previous_scene
	scene.queue_free()


func test_character_create_afterimage_forwards_snapshot_to_root_pool_and_restarts_timer() -> void:
	var tree := get_tree()
	var previous_scene: Node = tree.current_scene
	var scene := Node2D.new()
	scene.name = "TempCharacterAfterimageScene"
	tree.root.add_child(scene)
	tree.current_scene = scene

	var existing_pool := tree.root.get_node_or_null("VfxPool")
	if existing_pool != null:
		tree.root.remove_child(existing_pool)

	var fake_pool := FakeVfxPool.new()
	fake_pool.name = "VfxPool"
	tree.root.add_child(fake_pool)

	var character := CharacterAfterimageProbe.new()
	scene.add_child(character)
	character.global_transform = Transform2D(0.35, Vector2(18.0, -7.0))
	character.afterimage_color = Color(0.8, 0.9, 1.0, 0.6)
	character.afterimage_duration = 0.13
	character.afterimage_final_scale = 0.72
	character._is_creating_afterimages = true

	var sprite := Sprite2D.new()
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.hframes = 2
	sprite.vframes = 3
	sprite.frame = 4
	sprite.flip_h = true
	sprite.offset = Vector2(3.0, -2.0)
	sprite.centered = false
	character.sprite_2d = sprite

	var restart_timer := Timer.new()
	restart_timer.wait_time = 1.0
	character.add_child(restart_timer)
	character.afterimage_timer = restart_timer
	restart_timer.stop()

	character._create_afterimage()

	assert_eq(fake_pool.call_count, 1, "Character should forward afterimage request through root VfxPool lookup")
	assert_false(restart_timer.is_stopped(), "Character should restart timer while afterimage effect is active")
	assert_eq(fake_pool.last_request.get("texture"), sprite.texture, "Forwarded request should include sprite texture")
	assert_eq(fake_pool.last_request.get("hframes"), sprite.hframes, "Forwarded request should include hframes")
	assert_eq(fake_pool.last_request.get("vframes"), sprite.vframes, "Forwarded request should include vframes")
	assert_eq(fake_pool.last_request.get("frame"), sprite.frame, "Forwarded request should include frame")
	assert_eq(fake_pool.last_request.get("transform"), character.global_transform, "Forwarded request should include character global transform")
	assert_eq(fake_pool.last_request.get("flip_h"), sprite.flip_h, "Forwarded request should include horizontal flip")
	assert_eq(fake_pool.last_request.get("offset"), sprite.offset, "Forwarded request should include sprite offset")
	assert_eq(fake_pool.last_request.get("centered"), sprite.centered, "Forwarded request should include centered flag")
	assert_eq(fake_pool.last_request.get("color"), character.afterimage_color, "Forwarded request should include configured afterimage color")
	assert_eq(fake_pool.last_request.get("duration"), character.afterimage_duration, "Forwarded request should include configured duration")
	assert_eq(fake_pool.last_request.get("final_scale"), character.afterimage_final_scale, "Forwarded request should include configured final scale")

	tree.root.remove_child(fake_pool)
	fake_pool.queue_free()
	if existing_pool != null:
		tree.root.add_child(existing_pool)
	tree.current_scene = previous_scene
	scene.queue_free()


func _new_vfx_pool() -> Node:
	var pool_script := load(VFX_POOL_SCRIPT_PATH)
	assert_ne(pool_script, null, "VfxPool script should exist at %s" % VFX_POOL_SCRIPT_PATH)
	if pool_script == null:
		return Node.new()
	return pool_script.new()

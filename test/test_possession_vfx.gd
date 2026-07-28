extends GutTest

const PossessionVfxScene := preload("res://Scenes/VFX/possession_vfx.tscn")


func test_possession_vfx_travels_then_releases_to_the_pool() -> void:
	var vfx := PossessionVfxScene.instantiate()
	var release_state := {"released": false}
	add_child_autofree(vfx)

	vfx.play_once(
		Vector2(16.0, 40.0),
		Vector2(96.0, 40.0),
		false,
		func() -> void:
			release_state["released"] = true
	)

	assert_true(vfx.visible)
	assert_false(vfx.get_node("TravelOrb").visible)

	await get_tree().create_timer(0.35, true, false, true).timeout

	var travel_orb := vfx.get_node("TravelOrb") as Sprite2D
	var trail_particles := vfx.get_node("TravelOrb/TrailParticles") as GPUParticles2D
	assert_true(travel_orb.visible)
	assert_true(trail_particles.emitting)
	assert_false(trail_particles.local_coords)
	assert_gt(travel_orb.global_position.y, 20.0)
	assert_lt(travel_orb.global_position.y, 40.0)

	await get_tree().create_timer(0.8, true, false, true).timeout

	assert_true(bool(release_state["released"]))
	assert_false(vfx.visible)

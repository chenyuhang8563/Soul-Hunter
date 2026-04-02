class_name CharacterLifecycle
extends RefCounted

var owner
var _hazard_check_timer := 0.0

func setup(character) -> void:
	owner = character

func on_health_changed(current_health: float, max_health: float) -> void:
	owner._get_ui_presenter().update_health(current_health, max_health)
	if owner.interaction_state != null:
		owner.interaction_state._update_possession_prompt_icon()

func apply_damage(amount: float, source: CharacterBody2D = null) -> void:
	if owner.is_developer_mode_active():
		return
	if owner.has_method("is_damage_invincible") and owner.is_damage_invincible():
		return
	owner.health.apply_damage(amount, source)

func add_posture(amount: float) -> void:
	if owner.is_dead:
		return
	owner.current_posture = minf(owner.max_posture, owner.current_posture + amount)
	owner.time_since_last_posture_increase = 0.0
	owner._get_ui_presenter().update_posture(owner.current_posture, owner.max_posture)

func heal(amount: float) -> void:
	owner.health.heal(amount)

func is_alive() -> bool:
	return owner.health.is_alive()

func get_hp_ratio() -> float:
	return owner.health.get_hp_ratio()

func on_damaged(_amount: float, _current_health: float, _max_health: float, source: CharacterBody2D) -> void:
	if owner.is_dead:
		return
	if source != null:
		var direction := signf(owner.global_position.x - source.global_position.x)
		if direction == 0.0:
			direction = 1.0 if randf() > 0.5 else -1.0
		owner.knockback_velocity = direction * owner.KNOCKBACK_VELOCITY
	else:
		owner.knockback_velocity = 0.0
	if owner.animation_player == null or not owner.animation_player.has_animation(owner.ANIM_HURT):
		return
	owner.is_hurt_playing = true
	owner._on_enter_hurt()
	if owner.animation_tree != null:
		owner.animation_tree.active = false
	owner.animation_player.play(owner.ANIM_HURT)

func on_died(_killer: CharacterBody2D) -> void:
	owner.is_dead = true
	if owner.has_method("clear_buffs"):
		owner.clear_buffs()
	owner.is_hurt_playing = false
	owner._clear_possessed_highlight()
	owner._clear_possession_prompt_icon()
	owner._clear_dialogue_prompt_icon()
	if owner.interaction_state != null:
		owner.interaction_state._clear_current_interaction_target()
	owner._set_corpse_collision_state()
	if owner.hp_bar != null:
		owner.hp_bar.visible = false
	if owner.posture_bar != null:
		owner.posture_bar.visible = false
	owner._on_enter_dead()
	if owner.animation_tree != null:
		owner.animation_tree.active = false
	if owner.animation_player != null and owner.animation_player.has_animation(owner.ANIM_DEATH):
		owner.animation_player.play(owner.ANIM_DEATH)
	owner.velocity = Vector2.ZERO
	if owner.auto_revive and owner.is_inside_tree():
		var timer: SceneTreeTimer = owner.get_tree().create_timer(maxf(0.0, owner.revive_delay))
		timer.timeout.connect(owner._on_revive_timeout)
	elif not owner.remove_after_death_animation:
		_schedule_corpse_cleanup()

func on_revive_timeout() -> void:
	if not owner.is_inside_tree() or not owner.is_dead:
		return
	revive()

func revive() -> void:
	if not owner.is_dead:
		return
	owner.is_dead = false
	owner.remove_after_death_animation = false
	owner.is_hurt_playing = false
	owner._restore_default_collision_state()
	owner.velocity = Vector2.ZERO
	if owner.revive_at_spawn:
		owner.global_position = owner.spawn_position
	if owner.animation_tree != null:
		owner.animation_tree.active = true
	if owner.hp_bar != null:
		owner.hp_bar.visible = true
	owner._on_revived()
	owner.health.setup(owner.get_stat_value(&"max_health", owner.stats.max_health))
	owner.current_posture = 0.0
	owner.time_since_last_posture_increase = 0.0
	owner._get_ui_presenter().update_posture(owner.current_posture, owner.max_posture)
	if owner.interaction_state != null:
		owner.interaction_state._update_possession_prompt_icon()
	owner._update_possessed_highlight()

func process(delta: float) -> void:
	_hazard_check_timer += delta
	if _hazard_check_timer >= owner.HAZARD_CHECK_INTERVAL:
		_check_environment_hazards()
		_hazard_check_timer = 0.0
	_check_fall_death()
	if owner.current_posture > 0.0:
		owner.time_since_last_posture_increase += delta
		if owner.time_since_last_posture_increase >= owner.posture_recovery_delay:
			owner.current_posture = maxf(0.0, owner.current_posture - owner.posture_recovery_rate * delta)
			owner._get_ui_presenter().update_posture(owner.current_posture, owner.max_posture)

func on_animation_finished(anim_name: StringName) -> void:
	if anim_name == owner.ANIM_DEATH and owner.is_dead and owner.remove_after_death_animation:
		owner.queue_free()
		return
	if owner.is_dead:
		return
	if anim_name == owner.ANIM_HURT:
		owner.is_hurt_playing = false
		if owner.animation_tree != null:
			owner.animation_tree.active = true
		owner._on_exit_hurt()

func consume_for_possession() -> void:
	if owner.is_dead:
		return
	owner.remove_after_death_animation = true
	owner.auto_revive = false
	owner.is_dead = true
	owner.is_hurt_playing = false
	owner._clear_possessed_highlight()
	owner._clear_possession_prompt_icon()
	owner.set_player_controlled(false)
	owner._on_enter_dead()
	if owner.animation_tree != null:
		owner.animation_tree.active = false
	owner.velocity = Vector2.ZERO
	if owner.animation_player == null or not owner.animation_player.has_animation(owner.ANIM_DEATH):
		owner.queue_free()
		return
	owner.animation_player.play(owner.ANIM_DEATH)

func _check_environment_hazards() -> void:
	if not owner.is_inside_tree():
		return
	var current_scene = owner.get_tree().current_scene
	var tilemap: TileMapLayer = TileMapUtils.get_tilemap_from_scene(current_scene)
	if not tilemap:
		return
	var foot_position = owner.global_position + Vector2(0, owner.HAZARD_CHECK_DEPTH)
	var map_coord = tilemap.local_to_map(tilemap.to_local(foot_position))
	var tile_data = tilemap.get_cell_tile_data(map_coord)
	if tile_data and tile_data.get_custom_data("is_spike"):
		if owner.name.contains("Slime") or owner.is_in_group("immune_to_spikes"):
			return
		apply_damage(9999.0, null)

func _check_fall_death() -> void:
	if owner.global_position.y > owner.FALL_DEATH_Y:
		apply_damage(9999.0, null)

func _schedule_corpse_cleanup() -> void:
	if owner.corpse_cleanup_delay <= 0.0 or not owner.is_inside_tree():
		return
	var timer: SceneTreeTimer = owner.get_tree().create_timer(owner.corpse_cleanup_delay)
	timer.timeout.connect(owner._on_corpse_cleanup_timeout)

func on_corpse_cleanup_timeout() -> void:
	if not owner.is_inside_tree() or not owner.is_dead or owner.is_player_controlled or owner.remove_after_death_animation:
		return
	_respawn_from_corpse()

func _respawn_from_corpse() -> void:
	var parent: Node = owner.get_parent()
	if parent == null or owner._respawn_scene_path.is_empty():
		owner.queue_free()
		return
	var packed_scene := load(owner._respawn_scene_path) as PackedScene
	if packed_scene == null:
		owner.queue_free()
		return
	var respawned: Node = packed_scene.instantiate()
	if respawned is Node2D:
		(respawned as Node2D).global_position = owner.spawn_position
	parent.add_child(respawned)
	owner.queue_free()

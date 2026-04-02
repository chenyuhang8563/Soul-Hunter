class_name CharacterControlState
extends RefCounted

const DetachModuleScript := preload("res://Character/Common/detach_module.gd")

var owner

func setup(character) -> void:
	owner = character
	if DetachModuleScript != null:
		owner.detach_module = DetachModuleScript.new()
		owner.detach_module.setup(owner)

func set_player_controlled(controlled: bool) -> void:
	if owner.is_player_controlled == controlled:
		return
	owner.is_player_controlled = controlled
	if not controlled:
		owner._clear_possessed_highlight()
		var disabled_camera: Camera2D = get_camera()
		if disabled_camera != null:
			disabled_camera.enabled = false
	if owner.is_inside_tree():
		if controlled:
			owner.add_to_group("player_controlled")
			var camera: Camera2D = get_camera()
			if camera != null:
				camera.enabled = true
				camera.make_current()
				if SceneManager.has_signal("camera_changed"):
					SceneManager.camera_changed.emit(camera)
		else:
			owner.remove_from_group("player_controlled")
	if owner.interaction_state != null:
		owner.interaction_state.on_control_mode_changed(controlled)
	owner._update_possessed_highlight()
	owner._on_control_mode_changed(controlled)

func get_camera() -> Camera2D:
	for child in owner.get_children():
		if child is Camera2D:
			return child as Camera2D
	return null

func is_player_input_blocked() -> bool:
	return owner.is_dead or DialogueManager.is_dialogue_active()

func try_manual_detach(delta: float) -> void:
	if not owner.is_player_controlled or owner.is_dead or is_player_input_blocked():
		return
	if owner.name.begins_with("Soldier") and owner.get_script().resource_path.ends_with("soldier.gd"):
		return
	if owner.detach_module != null:
		owner.detach_module.update(delta)

func is_detach_blocking_movement() -> bool:
	if owner.detach_module != null and owner.detach_module.has_method("is_blocking_movement"):
		return owner.detach_module.is_blocking_movement()
	return false

func apply_common_gravity(delta: float) -> void:
	if is_developer_mode_active():
		owner.velocity.y = 0.0
		return
	if owner.dash_time_left > 0.0:
		return
	if not owner.is_on_floor():
		owner.velocity.y += owner.gravity * delta
	elif owner.velocity.y > 0:
		owner.velocity.y = 0

func apply_dash_physics(delta: float) -> bool:
	if owner.dash_time_left > 0.0:
		owner.dash_time_left -= delta
		owner.velocity = owner.dash_velocity
		if owner.dash_time_left <= 0.0 and owner.has_method("finish_dash"):
			owner.finish_dash()
		return true
	return false

func try_start_dash() -> void:
	if not owner.is_player_controlled or owner.is_dead or is_player_input_blocked():
		return
	if not InputMap.has_action("dash") or not Input.is_action_just_pressed("dash"):
		return
	if not owner.has_method("start_dash"):
		return
	owner.start_dash(owner.get_facing_direction())

func apply_knockback_physics(delta: float) -> void:
	if owner.knockback_velocity != 0.0:
		owner.knockback_velocity = move_toward(owner.knockback_velocity, 0.0, owner.KNOCKBACK_DECAY * delta)
	owner.velocity.x = owner.knockback_velocity

func try_common_jump() -> void:
	if is_developer_mode_active() or is_player_input_blocked():
		return
	if not owner.is_player_controlled or is_detach_blocking_movement():
		return
	if InputMap.has_action("ui_accept") and Input.is_action_just_pressed("ui_accept") and owner.is_on_floor():
		owner.velocity.y = -owner.jump_velocity

func get_player_move_speed() -> float:
	if owner.has_method("get_stat_value"):
		return float(owner.get_stat_value(&"move_speed", owner.player_move_speed))
	return float(owner.player_move_speed)

func get_developer_move_speed() -> float:
	var base_move_speed: float = float(owner.player_move_speed)
	if owner.has_method("get_stat_value"):
		base_move_speed = float(owner.get_stat_value(&"move_speed", owner.player_move_speed))
	return base_move_speed * owner.DEVELOPER_SPEED_MULTIPLIER

func is_developer_mode_active() -> bool:
	return DeveloperMode.applies_to(owner)

func try_toggle_developer_mode() -> void:
	if not owner.is_player_controlled or DialogueManager.is_dialogue_active():
		return
	if not InputMap.has_action("developer_mode_toggle"):
		return
	if Input.is_action_just_pressed("developer_mode_toggle"):
		DeveloperMode.toggle()

func apply_developer_flight_movement() -> bool:
	if not is_developer_mode_active() or is_player_input_blocked():
		return false
	var input_x := Input.get_axis("ui_left", "ui_right")
	var input_y := Input.get_axis("ui_up", "ui_down")
	var move_speed := get_developer_move_speed()
	owner.velocity.x = input_x * move_speed
	owner.velocity.y = input_y * move_speed
	var sprite: Sprite2D = owner._find_self_sprite() as Sprite2D
	if sprite != null and input_x != 0.0:
		sprite.flip_h = input_x < 0.0
	owner._set_locomotion_conditions(input_x)
	return true

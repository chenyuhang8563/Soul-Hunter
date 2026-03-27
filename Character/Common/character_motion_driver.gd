class_name CharacterMotionDriver
extends RefCounted

var owner
var sprite: Sprite2D
var air_move_multiplier := 1.0
var allow_detach := false

func setup(character, sprite_node: Sprite2D, move_multiplier: float, can_detach: bool) -> void:
	owner = character
	sprite = sprite_node
	air_move_multiplier = move_multiplier
	allow_detach = can_detach

func physics_process(delta: float) -> void:
	if owner.is_dead:
		return
	if owner.apply_dash_physics(delta):
		owner.move_and_slide()
		return
	owner.apply_common_gravity(delta)
	if owner.is_hurt_playing:
		owner.apply_knockback_physics(delta)
		owner.move_and_slide()
		return
	if owner.is_player_controlled:
		_physics_process_player(delta)
		return
	owner._physics_process_ai_default(delta)

func _physics_process_player(delta: float) -> void:
	var attack_target: Node2D = null
	if owner.ai_module != null and owner.ai_module.has_method("find_player_attack_target"):
		attack_target = owner.ai_module.find_player_attack_target()
	var target_in_scope: bool = attack_target != null
	if owner.attack_module != null and owner.attack_module.has_method("update"):
		owner.attack_module.update(delta, attack_target, target_in_scope)
	if not owner.is_player_input_blocked():
		if owner.has_method("_handle_player_attack_input"):
			owner._handle_player_attack_input()
		owner.try_common_jump()
		owner.try_manual_possession()
		if allow_detach:
			owner.try_manual_detach(delta)
	if owner.apply_developer_flight_movement():
		owner.move_and_slide()
		return
	if owner.is_detach_blocking_movement():
		owner.velocity.x = 0.0
		owner._set_locomotion_conditions(0.0)
		owner.move_and_slide()
		return
	var input_dir := 0.0
	if not owner.is_player_input_blocked():
		input_dir = Input.get_axis("ui_left", "ui_right")
	if input_dir != 0.0 and sprite != null:
		sprite.flip_h = input_dir < 0.0
	var can_move: bool = owner.attack_module == null or bool(owner.attack_module.can_move())
	if can_move:
		var move_speed: float = 0.0
		move_speed = owner.get_player_move_speed()
		if not owner.is_on_floor():
			move_speed *= air_move_multiplier
		owner.velocity.x = input_dir * move_speed
		owner._set_locomotion_conditions(input_dir)
	else:
		owner.velocity.x = 0.0
		owner._set_locomotion_conditions(0.0)
	owner.move_and_slide()

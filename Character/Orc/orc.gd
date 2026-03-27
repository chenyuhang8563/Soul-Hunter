extends "res://Character/Common/character.gd"

const AI_WALK_SPEED := 50.0
const RETURN_TOLERANCE := 6.0
const PARAM_IS_WALKING := "parameters/locomotion_state_machine/conditions/is_walking"
const PARAM_IS_IDLE := "parameters/locomotion_state_machine/conditions/is_idle"
const OrcAttackModuleScript := preload("res://Character/Common/orc_attack_module.gd")
const AIModuleScript := preload("res://Character/Common/ai_module.gd")

@onready var sprite: Sprite2D = $Sprite2D
@onready var home_marker: Marker2D = $Marker2D
@onready var visual_scope: Area2D = $VisualScope
@onready var attack_scope: Area2D = $AttackScope
@onready var line_of_sight: RayCast2D = $RayCast2D

@export var attack_cooldown := 0.30

func _on_character_ready() -> void:
	attack_module = OrcAttackModuleScript.new()
	ai_module = AIModuleScript.new()
	if not is_player_controlled:
		team_id = 1
		auto_revive = false
	_set_locomotion_conditions(0.0)
	visual_scope.monitoring = true
	attack_scope.monitoring = true
	attack_module.setup(self, sprite, animation_tree, null, null, null, stats, attack_cooldown)
	ai_module.setup(self, sprite, visual_scope, attack_scope, line_of_sight, attack_module, AI_WALK_SPEED, RETURN_TOLERANCE)
	ai_module.set_home_position(home_marker.global_position)

# Removed _on_control_mode_changed - now handled by base class

# Removed _on_enter_hurt - moved to base override hooks in character.gd

# Removed _on_enter_dead - moved to base override hooks in character.gd

# Removed _on_revived - moved to base override hooks in character.gd

# Removed _set_locomotion_conditions - now provided by base class

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if apply_dash_physics(delta):
		move_and_slide()
		return

	apply_common_gravity(delta)

	if is_hurt_playing:
		apply_knockback_physics(delta)
		move_and_slide()
		return

	if is_player_controlled:
		_physics_process_player(delta)
		return
	_physics_process_ai_default(delta)

func _physics_process_player(delta: float) -> void:
	var attack_target: Node2D = ai_module.find_player_attack_target()
	var target_in_scope := attack_target != null
	attack_module.update(delta, attack_target, target_in_scope)
	if attack_module.can_start_attack():
		if InputMap.has_action("hard_attack") and Input.is_action_just_pressed("hard_attack"):
			attack_module.start_attack(false)
		elif InputMap.has_action("light_attack") and Input.is_action_just_pressed("light_attack"):
			attack_module.start_attack(true)
	try_common_jump()
	try_manual_possession()
	try_manual_detach(delta)
	if apply_developer_flight_movement():
		move_and_slide()
		return
	
	if is_detach_blocking_movement():
		velocity.x = 0.0
		_set_locomotion_conditions(0.0)
		move_and_slide()
		return

	var input_dir := Input.get_axis("ui_left", "ui_right")
	if input_dir != 0:
		sprite.flip_h = input_dir < 0
	if attack_module.can_move():
		velocity.x = input_dir * get_player_move_speed()
		_set_locomotion_conditions(input_dir)
	else:
		velocity.x = 0.0
		_set_locomotion_conditions(0.0)
	move_and_slide()

# Removed _physics_process_ai - AI handled by base _physics_process_ai_default

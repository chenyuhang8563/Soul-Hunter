extends "res://Character/Common/character.gd"

const AIR_MOVE_MULTIPLIER := 1.35
const AI_WALK_SPEED := 50.0
const RETURN_TOLERANCE := 6.0
const PARAM_IS_WALKING := "parameters/locomotion_state_machine/conditions/is_walking"
const PARAM_IS_IDLE := "parameters/locomotion_state_machine/conditions/is_idle"
const SwordsmanAttackModuleScript := preload("res://Character/Common/swordsman_attack_module.gd")
const AIModuleScript := preload("res://Character/Common/ai_module.gd")

@onready var sprite: Sprite2D = $Swordsman
@onready var melee_hitbox: Area2D = $MeleeHitbox
@onready var melee_hitbox_shape: CollisionShape2D = $MeleeHitbox/CollisionShape2D
@onready var home_marker: Marker2D = $Marker2D
@onready var visual_scope: Area2D = $VisualScope
@onready var attack_scope: Area2D = $AttackScope
@onready var line_of_sight: RayCast2D = $RayCast2D

func _on_character_ready() -> void:
	attack_module = SwordsmanAttackModuleScript.new()
	ai_module = AIModuleScript.new()
	if is_player_controlled:
		team_id = 0
	else:
		team_id = 1
		auto_revive = false
	_set_locomotion_conditions(0.0)
	visual_scope.monitoring = true
	attack_scope.monitoring = true
	attack_module.setup(self, sprite, animation_tree, animation_player, melee_hitbox, melee_hitbox_shape, stats)
	ai_module.setup(self, sprite, visual_scope, attack_scope, line_of_sight, attack_module, AI_WALK_SPEED, RETURN_TOLERANCE)
	ai_module.set_home_position(home_marker.global_position)

# Removed _on_control_mode_changed - now handled by base class

# Removed _on_enter_hurt - moved to base override hooks in character.gd

# Removed _on_enter_dead - moved to base override hooks in character.gd
#	visual_scope.monitoring = false
#	attack_scope.monitoring = false

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
	attack_module.try_start_from_input()
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
	var can_move: bool = bool(attack_module.can_move())
	if can_move:
		var move_speed := get_player_move_speed() * (AIR_MOVE_MULTIPLIER if not is_on_floor() else 1.0)
		velocity.x = input_dir * move_speed
		_set_locomotion_conditions(input_dir)
	else:
		velocity.x = 0.0
		_set_locomotion_conditions(0.0)
	move_and_slide()

# Removed _physics_process_ai - AI handled by base _physics_process_ai_default

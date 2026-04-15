extends "res://Character/Common/character.gd"

const AIR_MOVE_MULTIPLIER := 1.35
const AI_WALK_SPEED_RATIO := 0.5
const RETURN_TOLERANCE := 6.0
const ArcherAttackModuleScript := preload("res://Character/Common/archer_attack_module.gd")
const AIModuleScript := preload("res://Character/Common/ai_module.gd")
const CharacterMotionDriverScript := preload("res://Character/Common/character_motion_driver.gd")

@onready var sprite: Sprite2D = $Sprite2D
@onready var home_marker: Marker2D = $Marker2D
@onready var visual_scope: Area2D = $VisualScope
@onready var attack_scope: Area2D = $AttackScope
@onready var line_of_sight: RayCast2D = $RayCast2D

@export var ai_enabled := false
@export var attack_cooldown := 0.36

var motion_driver: CharacterMotionDriver

func _on_character_ready() -> void:
	attack_module = ArcherAttackModuleScript.new()
	ai_module = AIModuleScript.new()
	motion_driver = CharacterMotionDriverScript.new()
	_set_locomotion_conditions(0.0)
	attack_module.setup(self, sprite, animation_tree, animation_player, null, null, stats, get_attack_speed_multiplier(), _resolve_audio_manager())
	ai_module.setup(self, sprite, visual_scope, attack_scope, line_of_sight, attack_module, get_player_move_speed() * AI_WALK_SPEED_RATIO, RETURN_TOLERANCE)
	ai_module.set_home_position(home_marker.global_position)
	motion_driver.setup(self, sprite, AIR_MOVE_MULTIPLIER, true)
	_refresh_runtime_mode()

func _physics_process(delta: float) -> void:
	if motion_driver != null:
		motion_driver.physics_process(delta)

func _handle_player_attack_input() -> void:
	if attack_module == null or not attack_module.can_start_attack():
		return
	if InputMap.has_action("hard_attack") and Input.is_action_just_pressed("hard_attack"):
		attack_module.start_attack(false)
	elif InputMap.has_action("light_attack") and Input.is_action_just_pressed("light_attack"):
		attack_module.start_attack(true)

func _on_control_mode_changed(is_controlled: bool) -> void:
	super._on_control_mode_changed(is_controlled)
	_refresh_runtime_mode()

func _on_revived_override() -> void:
	super._on_revived_override()
	_refresh_runtime_mode()

func _refresh_runtime_mode() -> void:
	var should_enable_enemy_ai := ai_enabled and not is_player_controlled and not is_interactable_npc
	var should_enable_attack_scope := is_player_controlled or should_enable_enemy_ai

	if is_player_controlled:
		team_id = 0
	elif should_enable_enemy_ai:
		team_id = 1
		auto_revive = false
	else:
		team_id = 0

	if visual_scope != null:
		visual_scope.monitoring = should_enable_enemy_ai
	if attack_scope != null:
		attack_scope.monitoring = should_enable_attack_scope
	if ai_module != null and ai_module.has_method("force_stop") and not should_enable_enemy_ai:
		ai_module.force_stop()

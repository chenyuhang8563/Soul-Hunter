extends "res://Character/Common/character.gd"

const AI_WALK_SPEED_RATIO := 0.5
const RETURN_TOLERANCE := 6.0
const OrcAttackModuleScript := preload("res://Character/Common/orc_attack_module.gd")
const AIModuleScript := preload("res://Character/Common/ai_module.gd")
const CharacterMotionDriverScript := preload("res://Character/Common/character_motion_driver.gd")

@onready var sprite: Sprite2D = $Sprite2D
@onready var home_marker: Marker2D = $Marker2D
@onready var visual_scope: Area2D = $VisualScope
@onready var attack_scope: Area2D = $AttackScope
@onready var line_of_sight: RayCast2D = $RayCast2D

var motion_driver: CharacterMotionDriver

func _on_character_ready() -> void:
	attack_module = OrcAttackModuleScript.new()
	ai_module = AIModuleScript.new()
	motion_driver = CharacterMotionDriverScript.new()
	if not is_player_controlled:
		team_id = 1
		auto_revive = false
	_set_locomotion_conditions(0.0)
	visual_scope.monitoring = true
	attack_scope.monitoring = true
	attack_module.setup(self, sprite, animation_tree, null, null, null, stats, get_attack_speed_multiplier(), _resolve_audio_manager())
	ai_module.setup(self, sprite, visual_scope, attack_scope, line_of_sight, attack_module, get_player_move_speed() * AI_WALK_SPEED_RATIO, RETURN_TOLERANCE)
	ai_module.set_home_position(home_marker.global_position)
	motion_driver.setup(self, sprite, 1.0, true)

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

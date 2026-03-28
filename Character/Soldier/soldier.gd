extends "res://Character/Common/character.gd"

const AIR_MOVE_MULTIPLIER := 1.35
const AI_WALK_SPEED_RATIO := 0.5
const RETURN_TOLERANCE := 6.0
const DEFAULT_ATTACK_COOLDOWN := 0.22
const SoldierAttackModuleScript := preload("res://Character/Common/soldier_attack_module.gd")
const AIModuleScript := preload("res://Character/Common/ai_module.gd")
const CharacterMotionDriverScript := preload("res://Character/Common/character_motion_driver.gd")

@onready var sprite: Sprite2D = $Soldier
@onready var melee_hitbox: Area2D = $MeleeHitbox
@onready var melee_hitbox_shape: CollisionShape2D = $MeleeHitbox/CollisionShape2D
@onready var home_marker: Marker2D = $Marker2D
@onready var visual_scope: Area2D = $VisualScope
@onready var attack_scope: Area2D = $AttackScope
@onready var line_of_sight: RayCast2D = $RayCast2D

var motion_driver: CharacterMotionDriver

func _on_character_ready() -> void:
	attack_module = SoldierAttackModuleScript.new()
	ai_module = AIModuleScript.new()
	motion_driver = CharacterMotionDriverScript.new()
	team_id = 0
	if get_tree().get_first_node_in_group("player_controlled") == null:
		set_player_controlled(true)
	if not is_player_controlled:
		team_id = 1
		auto_revive = false
	_set_locomotion_conditions(0.0)
	visual_scope.monitoring = true
	attack_scope.monitoring = true
	attack_module.setup(self, sprite, animation_tree, null, melee_hitbox, melee_hitbox_shape, stats, get_attack_cooldown(DEFAULT_ATTACK_COOLDOWN), AudioManager)
	ai_module.setup(self, sprite, visual_scope, attack_scope, line_of_sight, attack_module, get_player_move_speed() * AI_WALK_SPEED_RATIO, RETURN_TOLERANCE)
	ai_module.set_home_position(home_marker.global_position)
	motion_driver.setup(self, sprite, AIR_MOVE_MULTIPLIER, false)

func _physics_process(delta: float) -> void:
	if motion_driver != null:
		motion_driver.physics_process(delta)

func _handle_player_attack_input() -> void:
	if attack_module != null and attack_module.has_method("try_start_from_input"):
		attack_module.try_start_from_input()

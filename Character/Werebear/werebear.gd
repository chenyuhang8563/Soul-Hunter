extends "res://Character/Common/character.gd"
class_name Werebear

const AIR_MOVE_MULTIPLIER := 1.35
const AI_WALK_SPEED_RATIO := 0.5
const RETURN_TOLERANCE := 6.0
const BOSS_ATTACK_MODULE_PATH := "res://Character/Common/werebear_boss_attack_module.gd"
const BOSS_AI_MODULE_PATH := "res://Character/Common/boss_ai_module.gd"
const FallbackAttackModuleScript := preload("res://Character/Common/swordsman_attack_module.gd")
const FallbackAIModuleScript := preload("res://Character/Common/ai_module.gd")
const CharacterMotionDriverScript := preload("res://Character/Common/character_motion_driver.gd")
const WerebearEnrageBuffScript := preload("res://Character/Common/Buffs/werebear_enrage_buff.gd")
const WerebearKnockbackResistBuffScript := preload("res://Character/Common/Buffs/werebear_knockback_resist_buff.gd")
const BossFightBgmStream := preload("res://Assets/SFX/boss_fight.wav")
const BOSS_ATTACK_SCOPE_SCALE := Vector2(4.0, 4.0)

@onready var sprite: Sprite2D = _find_self_sprite()
@onready var melee_hitbox: Area2D = $MeleeHitbox
@onready var melee_hitbox_shape: CollisionShape2D = $MeleeHitbox/CollisionShape2D
@onready var home_marker: Marker2D = $Marker2D
@onready var visual_scope: Area2D = $VisualScope
@onready var attack_scope: Area2D = $AttackScope
@onready var attack_scope_shape: CollisionShape2D = $AttackScope/CollisionShape2D
@onready var line_of_sight: RayCast2D = $RayCast2D

@export var phase_two_health_ratio := 0.5
@export var boss_ai_enabled := true
@export var reactive_backstep_distance := 20.0
@export var reactive_backstep_chance := 0.2

var motion_driver: CharacterMotionDriver
var current_phase := 1
var phase_two_triggered := false

func _on_character_ready() -> void:
	attack_module = _create_attack_module()
	ai_module = _create_ai_module()
	motion_driver = CharacterMotionDriverScript.new()
	current_phase = 1
	phase_two_triggered = false
	_set_locomotion_conditions(0.0)
	if attack_scope_shape != null:
		attack_scope_shape.scale = BOSS_ATTACK_SCOPE_SCALE
	if attack_module != null and attack_module.has_method("setup"):
		attack_module.setup(self, sprite, animation_tree, animation_player, melee_hitbox, melee_hitbox_shape, stats, get_attack_speed_multiplier(), _resolve_audio_manager())
	if ai_module != null and ai_module.has_method("setup"):
		ai_module.setup(self, sprite, visual_scope, attack_scope, line_of_sight, attack_module, get_player_move_speed() * AI_WALK_SPEED_RATIO, RETURN_TOLERANCE)
	if ai_module != null and ai_module.has_method("set_home_position"):
		ai_module.set_home_position(home_marker.global_position)
	motion_driver.setup(self, sprite, AIR_MOVE_MULTIPLIER, true)
	_refresh_runtime_mode()
	_refresh_boss_ai_walk_speed()
	_request_boss_bgm()

func _physics_process(delta: float) -> void:
	if motion_driver != null:
		motion_driver.physics_process(delta)
	_update_boss_phase()

func _handle_player_attack_input() -> void:
	if attack_module == null:
		return
	if attack_module.has_method("try_start_from_input"):
		attack_module.try_start_from_input()
		return
	if not attack_module.can_start_attack():
		return
	if InputMap.has_action("hard_attack") and Input.is_action_just_pressed("hard_attack") and attack_module.has_method("start_attack"):
		attack_module.start_attack(false)
	elif InputMap.has_action("light_attack") and Input.is_action_just_pressed("light_attack") and attack_module.has_method("start_attack"):
		attack_module.start_attack(true)

func _on_control_mode_changed(is_controlled: bool) -> void:
	super._on_control_mode_changed(is_controlled)
	_refresh_runtime_mode()

func _on_enter_hurt_override() -> void:
	if attack_module != null and attack_module.has_method("blocks_hurt_interrupt") and attack_module.blocks_hurt_interrupt():
		_set_locomotion_conditions(0.0)
		return
	super._on_enter_hurt_override()

func _on_damaged(_amount: float, _current_health: float, _max_health: float, source: CharacterBody2D) -> void:
	if _amount <= 0.0:
		super._on_damaged(_amount, _current_health, _max_health, source)
		return
	super._on_damaged(_amount, _current_health, _max_health, source)
	if attack_module != null and attack_module.has_method("notify_damage_taken"):
		attack_module.call("notify_damage_taken", _amount, source)

func _on_revived_override() -> void:
	super._on_revived_override()
	_refresh_runtime_mode()

func _update_boss_phase() -> void:
	if phase_two_triggered or not is_alive():
		return
	var clamped_ratio := clampf(phase_two_health_ratio, 0.0, 1.0)
	if get_hp_ratio() > clamped_ratio:
		return
	phase_two_triggered = true
	current_phase = 2
	_apply_phase_two_enrage()
	_apply_phase_two_knockback_resist()
	if attack_module != null and attack_module.has_method("enter_phase_two"):
		attack_module.enter_phase_two()
	if ai_module != null and ai_module.has_method("enter_phase_two"):
		ai_module.enter_phase_two()
	_refresh_boss_ai_walk_speed()

func is_phase_two() -> bool:
	return phase_two_triggered

func _refresh_boss_ai_walk_speed() -> void:
	if ai_module != null and ai_module.has_method("refresh_walk_speed"):
		ai_module.call("refresh_walk_speed", get_player_move_speed() * AI_WALK_SPEED_RATIO)

func _apply_phase_two_enrage() -> void:
	if buff_controller == null or buff_controller.has_buff(&"werebear_enrage"):
		return
	add_buff(WerebearEnrageBuffScript.new())
	_refresh_boss_ai_walk_speed()

func _apply_phase_two_knockback_resist() -> void:
	if buff_controller == null or buff_controller.has_buff(&"werebear_knockback_resist"):
		return
	add_buff(WerebearKnockbackResistBuffScript.new())

func _request_boss_bgm() -> void:
	if not boss_ai_enabled or is_player_controlled or is_interactable_npc:
		return
	var audio_manager := _resolve_audio_manager()
	if audio_manager != null and audio_manager.has_method("play_bgm_stream"):
		audio_manager.play_bgm_stream(BossFightBgmStream)

func _refresh_runtime_mode() -> void:
	var should_enable_enemy_ai := boss_ai_enabled and not is_player_controlled and not is_interactable_npc
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

func _create_attack_module() -> AttackModuleBase:
	var script := _load_optional_script(BOSS_ATTACK_MODULE_PATH, FallbackAttackModuleScript)
	if script == null:
		return null
	return script.new()

func _create_ai_module() -> RefCounted:
	var script := _load_optional_script(BOSS_AI_MODULE_PATH, FallbackAIModuleScript)
	if script == null:
		return null
	return script.new()

func _load_optional_script(path: String, fallback_script: Script) -> Script:
	if ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is Script:
			return loaded
	return fallback_script

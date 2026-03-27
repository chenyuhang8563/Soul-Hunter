extends CharacterBody2D

signal npc_interacted(interactor: CharacterBody2D)

const ANIM_HURT := "hurt"
const ANIM_DEATH := "death"
const HintIconScene := preload("res://Scenes/icon.tscn")
const PossessionOutlineShader := preload("res://Shaders/possession_outline.gdshader")
const CharacterUIPresenterScript := preload("res://Character/Common/character_ui_presenter.gd")
const CharacterLifecycleScript := preload("res://Character/Common/character_lifecycle.gd")
const CharacterInteractionScript := preload("res://Character/Common/character_interaction.gd")
const CharacterControlStateScript := preload("res://Character/Common/character_control_state.gd")

const KNOCKBACK_VELOCITY := 140.0
const KNOCKBACK_DECAY := 490.0
const FALL_DEATH_Y := 500.0
const HAZARD_CHECK_DEPTH := 5.0
const DEVELOPER_SPEED_MULTIPLIER := 2.0
const HAZARD_CHECK_INTERVAL := 0.1
const PROMPT_ICON_UPDATE_INTERVAL := 0.05

@onready var hp_bar: ProgressBar = get_node_or_null("HPBar")
@onready var posture_bar: ProgressBar = get_node_or_null("PostureBar")
@onready var animation_tree: AnimationTree = get_node_or_null("AnimationTree")
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer")

@export var stats: CharacterStats
@export var auto_revive := true
@export var revive_delay := 2.0
@export var revive_at_spawn := true
@export var team_id := 0
@export var can_be_possessed := true
@export var start_player_controlled := false
@export var gravity := 900.0
@export var jump_velocity := 280.0
@export var player_move_speed := 100.0
@export var possession_range := 200.0
@export var possession_hp_threshold := 0.2
@export var possession_hint_height := 20.0
@export var is_interactable_npc := false
@export var dialogue_range := 40.0
@export var corpse_cleanup_delay := 10.0

var ai_module: RefCounted = null
var attack_module: AttackModuleBase = null
var lifecycle_state: CharacterLifecycle = null
var interaction_state: CharacterInteraction = null
var control_state: CharacterControlState = null

var dash_velocity: Vector2 = Vector2.ZERO
var dash_time_left: float = 0.0
var detach_module: DetachModule = null

var health := HealthComponent.new()
var is_dead := false
var is_hurt_playing := false
var ui_presenter = null
var _ui_presenter_initialized := false
var spawn_position := Vector2.ZERO
var is_player_controlled := false
var possession_prompt_icon: Node2D
var dialogue_prompt_icon: Node2D
var possessed_highlight_sprite: Sprite2D
var possessed_highlight_prev_material: Material
var possessed_highlight_material: ShaderMaterial
var remove_after_death_animation := false

var max_posture := 100.0
var current_posture := 0.0
var posture_recovery_delay := 2.0
var posture_recovery_rate := 30.0
var time_since_last_posture_increase := 0.0
var knockback_velocity := 0.0
var _default_collision_layer := 0
var _default_collision_mask := 0
var _respawn_scene_path := ""

func _ready() -> void:
	if stats == null:
		stats = CharacterStats.new()
	spawn_position = global_position
	_default_collision_layer = collision_layer
	_default_collision_mask = collision_mask
	_respawn_scene_path = scene_file_path
	_get_ui_presenter().setup(hp_bar, posture_bar)
	if animation_tree != null:
		animation_tree.active = true
	if animation_player != null and not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)
	_setup_helpers()
	_setup_health()
	add_to_group("possessable_character")
	set_player_controlled(start_player_controlled)
	if interaction_state != null:
		interaction_state.on_ready()
	_on_character_ready()

func _setup_helpers() -> void:
	lifecycle_state = CharacterLifecycleScript.new()
	lifecycle_state.setup(self)
	interaction_state = CharacterInteractionScript.new()
	interaction_state.setup(self)
	control_state = CharacterControlStateScript.new()
	control_state.setup(self)

func _on_character_ready() -> void:
	pass

func _exit_tree() -> void:
	if health.health_changed.is_connected(_on_health_changed):
		health.health_changed.disconnect(_on_health_changed)
	if health.damaged.is_connected(_on_damaged):
		health.damaged.disconnect(_on_damaged)
	if health.died.is_connected(_on_died):
		health.died.disconnect(_on_died)
	if animation_player != null and animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.disconnect(_on_animation_finished)
	if interaction_state != null:
		interaction_state._clear_current_interaction_target()

func _set_locomotion_conditions(input_dir: float) -> void:
	if animation_tree == null:
		return
	var is_walking := absf(input_dir) > 0.01
	animation_tree.set("parameters/locomotion_state_machine/conditions/is_walking", is_walking)
	animation_tree.set("parameters/locomotion_state_machine/conditions/is_idle", not is_walking)

func _set_scope_monitoring(enabled: bool) -> void:
	var visual_scope = get_node_or_null("VisualScope")
	var attack_scope = get_node_or_null("AttackScope")
	if visual_scope:
		visual_scope.monitoring = enabled
	if attack_scope:
		attack_scope.monitoring = enabled

func _on_control_mode_changed(is_controlled: bool) -> void:
	auto_revive = is_controlled

func _on_enter_hurt_override() -> void:
	if ai_module != null:
		if ai_module.has_method("interrupt_attack"):
			ai_module.interrupt_attack()
		elif ai_module.has_method("force_stop"):
			ai_module.force_stop()
	_set_locomotion_conditions(0.0)

func _on_enter_dead_override() -> void:
	if ai_module != null and ai_module.has_method("force_stop"):
		ai_module.force_stop()
	_set_locomotion_conditions(0.0)
	_set_scope_monitoring(false)

func _on_revived_override() -> void:
	if ai_module != null and ai_module.has_method("force_stop"):
		ai_module.force_stop()
	_set_locomotion_conditions(0.0)
	_set_scope_monitoring(true)

func _physics_process_ai_default(delta: float) -> void:
	if ai_module == null:
		return
	var input_dir = ai_module.physics_process_ai(delta)
	_set_locomotion_conditions(input_dir)
	move_and_slide()

func _get_ui_presenter():
	if not _ui_presenter_initialized:
		_ui_presenter_initialized = true
		ui_presenter = CharacterUIPresenterScript.new()
	return ui_presenter

func _setup_health() -> void:
	health.health_changed.connect(_on_health_changed)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	health.setup(stats.max_health)

func _on_health_changed(current_health: float, max_health: float) -> void:
	if lifecycle_state != null:
		lifecycle_state.on_health_changed(current_health, max_health)

func apply_damage(amount: float, source: CharacterBody2D = null) -> void:
	if lifecycle_state != null:
		lifecycle_state.apply_damage(amount, source)

func add_posture(amount: float) -> void:
	if lifecycle_state != null:
		lifecycle_state.add_posture(amount)

func is_posture_broken() -> bool:
	return current_posture >= max_posture

func heal(amount: float) -> void:
	if lifecycle_state != null:
		lifecycle_state.heal(amount)

func is_alive() -> bool:
	return lifecycle_state != null and lifecycle_state.is_alive()

func get_hp_ratio() -> float:
	if lifecycle_state == null:
		return 0.0
	return lifecycle_state.get_hp_ratio()

func _on_damaged(_amount: float, _current_health: float, _max_health: float, source: CharacterBody2D) -> void:
	if lifecycle_state != null:
		lifecycle_state.on_damaged(_amount, _current_health, _max_health, source)

func _on_died(_killer: CharacterBody2D) -> void:
	if lifecycle_state != null:
		lifecycle_state.on_died(_killer)

func _on_revive_timeout() -> void:
	if lifecycle_state != null:
		lifecycle_state.on_revive_timeout()

func revive() -> void:
	if lifecycle_state != null:
		lifecycle_state.revive()

func set_player_controlled(controlled: bool) -> void:
	if control_state != null:
		control_state.set_player_controlled(controlled)

func _get_camera() -> Camera2D:
	if control_state == null:
		return null
	return control_state.get_camera()

func try_manual_possession() -> void:
	if interaction_state != null:
		interaction_state.try_manual_possession()

func try_manual_detach(delta: float) -> void:
	if control_state != null:
		control_state.try_manual_detach(delta)

func is_detach_blocking_movement() -> bool:
	if control_state == null:
		return false
	return control_state.is_detach_blocking_movement()

func receive_possession_from(possessor: CharacterBody2D) -> bool:
	if interaction_state == null:
		return false
	return interaction_state.receive_possession_from(possessor)

func can_be_possessed_now() -> bool:
	if interaction_state == null:
		return false
	return interaction_state.can_be_possessed_now()

func is_player_character() -> bool:
	return is_player_controlled

func get_team_id() -> int:
	return team_id

func can_interact(interactor: CharacterBody2D) -> bool:
	if interaction_state == null:
		return false
	return interaction_state.can_interact(interactor)

func interact(interactor: CharacterBody2D) -> void:
	if interaction_state != null:
		interaction_state.interact(interactor)

func set_interaction_prompt_visible(show_prompt: bool) -> void:
	if interaction_state != null:
		interaction_state.set_interaction_prompt_visible(show_prompt)

func _process(delta: float) -> void:
	if control_state != null:
		control_state.try_toggle_developer_mode()
	if interaction_state != null:
		interaction_state.process(delta)
	if is_dead:
		return
	if lifecycle_state != null:
		lifecycle_state.process(delta)

func apply_common_gravity(delta: float) -> void:
	if control_state != null:
		control_state.apply_common_gravity(delta)

func apply_dash_physics(delta: float) -> bool:
	if control_state == null:
		return false
	return control_state.apply_dash_physics(delta)

func apply_knockback_physics(delta: float) -> void:
	if control_state != null:
		control_state.apply_knockback_physics(delta)

func try_common_jump() -> void:
	if control_state != null:
		control_state.try_common_jump()

func get_player_move_speed() -> float:
	if control_state == null:
		return player_move_speed
	return control_state.get_player_move_speed()

func get_developer_move_speed() -> float:
	if control_state == null:
		return player_move_speed * DEVELOPER_SPEED_MULTIPLIER
	return control_state.get_developer_move_speed()

func is_developer_mode_active() -> bool:
	if control_state == null:
		return false
	return control_state.is_developer_mode_active()

func try_toggle_developer_mode() -> void:
	if control_state != null:
		control_state.try_toggle_developer_mode()

func apply_developer_flight_movement() -> bool:
	if control_state == null:
		return false
	return control_state.apply_developer_flight_movement()

func is_player_input_blocked() -> bool:
	if control_state == null:
		return false
	return control_state.is_player_input_blocked()

func _ensure_hint_icon(current_icon: Node2D, texture: Texture2D) -> Node2D:
	if current_icon == null:
		current_icon = HintIconScene.instantiate() as Node2D
		if current_icon != null:
			var sprite = current_icon as Sprite2D
			if sprite == null:
				sprite = current_icon.get_node_or_null("Sprite2D")
			if sprite:
				sprite.texture = texture
			add_child(current_icon)
	if current_icon != null:
		current_icon.position = Vector2(0.0, -possession_hint_height)
		var icon_sprite = current_icon as Sprite2D
		if icon_sprite == null:
			icon_sprite = current_icon.get_node_or_null("Sprite2D")
		if icon_sprite and icon_sprite.texture != texture:
			icon_sprite.texture = texture
	return current_icon

func _clear_possession_prompt_icon() -> void:
	possession_prompt_icon = _clear_hint_icon(possession_prompt_icon)

func _clear_dialogue_prompt_icon() -> void:
	dialogue_prompt_icon = _clear_hint_icon(dialogue_prompt_icon)

func _clear_hint_icon(current_icon: Node2D) -> Node2D:
	if current_icon != null and is_instance_valid(current_icon):
		current_icon.queue_free()
	return null

func _update_possessed_highlight() -> void:
	if not is_player_controlled or is_dead:
		_clear_possessed_highlight()
		return
	var sprite := _find_self_sprite()
	if sprite == null:
		_clear_possessed_highlight()
		return
	if possessed_highlight_sprite == sprite and sprite.material == possessed_highlight_material:
		return
	_clear_possessed_highlight()
	if possessed_highlight_material == null:
		possessed_highlight_material = ShaderMaterial.new()
		possessed_highlight_material.shader = PossessionOutlineShader
	possessed_highlight_sprite = sprite
	possessed_highlight_prev_material = sprite.material
	possessed_highlight_sprite.material = possessed_highlight_material

func _clear_possessed_highlight() -> void:
	if possessed_highlight_sprite != null and is_instance_valid(possessed_highlight_sprite):
		possessed_highlight_sprite.material = possessed_highlight_prev_material
	possessed_highlight_sprite = null
	possessed_highlight_prev_material = null

func _find_self_sprite() -> Sprite2D:
	var sprite := get_node_or_null("Soldier") as Sprite2D
	if sprite != null:
		return sprite
	sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		return sprite
	for child in get_children():
		if child is Sprite2D:
			return child as Sprite2D
	return null

func _on_animation_finished(anim_name: StringName) -> void:
	if lifecycle_state != null:
		lifecycle_state.on_animation_finished(anim_name)

func consume_for_possession() -> void:
	if lifecycle_state != null:
		lifecycle_state.consume_for_possession()

func _on_enter_hurt() -> void:
	_on_enter_hurt_override()

func _on_exit_hurt() -> void:
	pass

func _on_enter_dead() -> void:
	_on_enter_dead_override()

func _on_revived() -> void:
	_on_revived_override()

func _set_corpse_collision_state() -> void:
	collision_layer = 0
	collision_mask = 1

func _restore_default_collision_state() -> void:
	collision_layer = _default_collision_layer
	collision_mask = _default_collision_mask

func _on_corpse_cleanup_timeout() -> void:
	if lifecycle_state != null:
		lifecycle_state.on_corpse_cleanup_timeout()

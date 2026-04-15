extends CharacterBody2D

@warning_ignore("unused_signal")
signal npc_interacted(interactor: CharacterBody2D)
signal damage_dealt(target, final_damage)
signal dash_finished(start_position, end_position)

const ANIM_HURT := "hurt"
const ANIM_DEATH := "death"
const HintIconScene := preload("res://Scenes/icon.tscn")
const PossessionOutlineShader := preload("res://Shaders/possession_outline.gdshader")
const HitFlashOverlayShader := preload("res://Shaders/hit_flash_overlay.gdshader")
const AudioManagerScript := preload("res://Global/audio_manager.gd")
const CharacterUIPresenterScript := preload("res://Character/Common/character_ui_presenter.gd")
const CharacterLifecycleScript := preload("res://Character/Common/character_lifecycle.gd")
const CharacterInteractionScript := preload("res://Character/Common/character_interaction.gd")
const CharacterControlStateScript := preload("res://Character/Common/character_control_state.gd")
const BuffContextScript := preload("res://Character/Common/Buffs/buff_context.gd")
const BuffControllerScript := preload("res://Character/Common/Buffs/buff_controller.gd")
const RunModifierControllerScript := preload("res://Character/Common/run_modifier_controller.gd")
const BUFF_ICON_MARGIN := Vector2(6.0, 6.0)
const BUFF_ICON_SPACING := 2.0

const KNOCKBACK_VELOCITY := 140.0
const KNOCKBACK_DECAY := 490.0
const FALL_DEATH_Y := 500.0
const HAZARD_CHECK_DEPTH := 5.0
const DEVELOPER_SPEED_MULTIPLIER := 2.0
const HAZARD_CHECK_INTERVAL := 0.1
const PROMPT_ICON_UPDATE_INTERVAL := 0.05
const WORLD_COLLISION_MASK := 1

@onready var hp_bar: ProgressBar = get_node_or_null("HPBar")
@onready var posture_bar: ProgressBar = get_node_or_null("PostureBar")
@onready var animation_tree: AnimationTree = get_node_or_null("AnimationTree")
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var damage_number_spawner: Node2D = get_node_or_null("DamageNumberSpawner")
@onready var sprite_2d: Sprite2D = get_node_or_null("Sprite2D")
@onready var afterimage_timer: Timer = get_node_or_null("AfterimageTimer")

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
@export var afterimage_enabled: bool = true
@export var afterimage_color: Color = Color(1,1,1,0.7)
@export var afterimage_interval: float = 0.05
@export var afterimage_duration: float = 0.4
@export var afterimage_final_scale: float = 0.8
@export var dash_enabled := true
@export var dash_speed := 280.0
@export var dash_duration := 0.18
@export var dash_cooldown := 0.45
@export var dash_invincibility_duration := 0.18


var ai_module: RefCounted = null
var attack_module: AttackModuleBase = null
var lifecycle_state: CharacterLifecycle = null
var interaction_state: CharacterInteraction = null
var control_state: CharacterControlState = null

var dash_velocity: Vector2 = Vector2.ZERO
var dash_time_left: float = 0.0
var detach_module: DetachModule = null

var health := HealthComponent.new()
var buff_context = null
var buff_controller = null
var run_modifier_controller: RunModifierController = null
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
var possession_combo_overlay_sprite: Sprite2D
var hit_flash_overlay_sprite: Sprite2D
var hit_flash_overlay_material: ShaderMaterial
var hit_flash_tween: Tween
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
var _buff_icon_nodes: Dictionary = {}
var _force_player_body_collision := false
var _pending_player_runtime_state: Dictionary = {}

var _is_creating_afterimages: bool = false
var dash_cooldown_left := 0.0
var invincibility_time_left := 0.0
var _dash_start_position := Vector2.ZERO
var _possession_input_lock_count := 0

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
	_setup_buff_system()
	_apply_pending_player_runtime_state()
	_clear_static_buff_icon_placeholder()
	_setup_health()
	add_to_group("possessable_character")
	set_player_controlled(start_player_controlled)
	if interaction_state != null:
		interaction_state.on_ready()
	_on_character_ready()

	# 应用自定义时间间隔并连接信号
	if afterimage_timer != null:
		afterimage_timer.wait_time = afterimage_interval
		if not afterimage_timer.timeout.is_connected(_create_afterimage):
			afterimage_timer.timeout.connect(_create_afterimage)

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
	_disconnect_buff_controller_signals()
	_disconnect_run_modifier_controller_signals()
	if animation_player != null and animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.disconnect(_on_animation_finished)
	if interaction_state != null:
		interaction_state._clear_current_interaction_target()
	_clear_possession_combo_overlay()
	_clear_hit_flash_overlay()
	_clear_all_buff_icons()

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
	finish_dash()
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
	health.setup(get_stat_value(&"max_health", stats.max_health))

func _setup_buff_system() -> void:
	buff_context = BuffContextScript.new()
	buff_context.setup(
		self,
		Callable(self, "get_base_stat_value"),
		Callable(self, "_receive_buff_damage"),
		Callable(self, "_receive_buff_heal"),
		Callable(self, "_is_buff_host_alive")
	)
	buff_controller = BuffControllerScript.new()
	buff_controller.setup(buff_context)
	_connect_buff_controller_signals()

func _connect_buff_controller_signals() -> void:
	if buff_controller == null:
		return
	buff_controller.stats_changed.connect(_on_buff_stats_changed)
	buff_controller.buff_added.connect(_on_buff_added)
	buff_controller.buff_removed.connect(_on_buff_removed)

func _connect_run_modifier_controller_signals() -> void:
	if run_modifier_controller == null:
		return
	if not run_modifier_controller.stats_changed.is_connected(_on_run_modifier_stats_changed):
		run_modifier_controller.stats_changed.connect(_on_run_modifier_stats_changed)

func _disconnect_buff_controller_signals() -> void:
	if buff_controller == null:
		return
	if buff_controller.stats_changed.is_connected(_on_buff_stats_changed):
		buff_controller.stats_changed.disconnect(_on_buff_stats_changed)
	if buff_controller.buff_added.is_connected(_on_buff_added):
		buff_controller.buff_added.disconnect(_on_buff_added)
	if buff_controller.buff_removed.is_connected(_on_buff_removed):
		buff_controller.buff_removed.disconnect(_on_buff_removed)

func _disconnect_run_modifier_controller_signals() -> void:
	if run_modifier_controller == null:
		return
	if run_modifier_controller.stats_changed.is_connected(_on_run_modifier_stats_changed):
		run_modifier_controller.stats_changed.disconnect(_on_run_modifier_stats_changed)

func _on_buff_stats_changed() -> void:
	_refresh_cached_stat_state()

func _on_run_modifier_stats_changed() -> void:
	_refresh_cached_stat_state()

func _refresh_cached_stat_state() -> void:
	if health != null:
		health.set_max_health(get_stat_value(&"max_health", stats.max_health))
	if attack_module != null and attack_module.has_method("set_attack_cooldown"):
		var base_cooldown: float = float(attack_module.base_attack_cooldown)
		attack_module.call("set_attack_cooldown", get_attack_cooldown(base_cooldown))
	if attack_module != null and attack_module.has_method("set_attack_speed_multiplier"):
		attack_module.call("set_attack_speed_multiplier", get_attack_speed_multiplier())

func _on_buff_added(buff) -> void:
	if buff == null or not buff.has_method("create_icon_instance"):
		_sync_possession_combo_overlay()
		return
	var icon = buff.create_icon_instance()
	if icon == null:
		_sync_possession_combo_overlay()
		return
	if icon.has_method("bind_buff"):
		icon.bind_buff(buff)
	add_child(icon)
	_buff_icon_nodes[buff.get_instance_id()] = {
		"buff": buff,
		"node": icon,
	}
	_refresh_buff_icon_positions()
	_sync_possession_combo_overlay()

func _on_buff_removed(buff) -> void:
	if buff == null:
		_sync_possession_combo_overlay()
		return
	var buff_id = int(buff.get_instance_id())
	if not _buff_icon_nodes.has(buff_id):
		_sync_possession_combo_overlay()
		return
	var entry: Dictionary = _buff_icon_nodes[buff_id]
	var icon = entry.get("node")
	if icon != null and is_instance_valid(icon):
		(icon as Node2D).queue_free()
	_buff_icon_nodes.erase(buff_id)
	_refresh_buff_icon_positions()
	_sync_possession_combo_overlay()

func _clear_static_buff_icon_placeholder() -> void:
	var placeholder = get_node_or_null("Buff Icon") as Node2D
	if placeholder != null:
		placeholder.queue_free()

func _clear_all_buff_icons() -> void:
	for entry in _buff_icon_nodes.values():
		var icon = entry.get("node")
		if icon != null and is_instance_valid(icon):
			(icon as Node2D).queue_free()
	_buff_icon_nodes.clear()

func _refresh_buff_icon_positions() -> void:
	var entries: Array[Dictionary] = []
	var stale_buff_ids: Array[int] = []
	for buff_id_variant in _buff_icon_nodes.keys():
		var buff_id := int(buff_id_variant)
		var entry: Dictionary = _buff_icon_nodes[buff_id]
		var buff = entry.get("buff")
		var icon = entry.get("node")
		if buff == null or not is_instance_valid(buff) or icon == null or not is_instance_valid(icon):
			stale_buff_ids.append(buff_id)
			continue
		entries.append(entry)
	for buff_id in stale_buff_ids:
		_buff_icon_nodes.erase(buff_id)
	entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_buff = left.get("buff")
		var right_buff = right.get("buff")
		if left_buff == null:
			return false
		if right_buff == null:
			return true
		return int(left_buff.get_meta("buff_sequence", 0)) < int(right_buff.get_meta("buff_sequence", 0))
	)
	var anchor: Vector2 = _get_buff_icon_anchor_position()
	var current_x: float = anchor.x
	for entry in entries:
		var icon = entry.get("node")
		if icon == null or not is_instance_valid(icon):
			continue
		var icon_node := icon as Node2D
		if icon_node == null:
			continue
		var half_width: float = _get_buff_icon_half_width(icon_node)
		icon_node.position = Vector2(current_x + half_width, anchor.y)
		current_x += half_width * 2.0 + BUFF_ICON_SPACING

func _get_buff_icon_anchor_position() -> Vector2:
	if hp_bar == null:
		return BUFF_ICON_MARGIN
	return Vector2(hp_bar.offset_right, hp_bar.offset_bottom) + BUFF_ICON_MARGIN

func _get_buff_icon_half_width(icon: Node2D) -> float:
	if icon is Sprite2D:
		var sprite = icon as Sprite2D
		if sprite.texture != null:
			return sprite.texture.get_size().x * absf(sprite.scale.x) * 0.5
	return 8.0

func _receive_buff_damage(amount: float, source: CharacterBody2D = null) -> void:
	if lifecycle_state != null:
		lifecycle_state.apply_damage(amount, source)

func _receive_buff_heal(amount: float) -> void:
	if lifecycle_state != null:
		lifecycle_state.heal(amount)

func _is_buff_host_alive() -> bool:
	if lifecycle_state != null:
		return lifecycle_state.is_alive()
	return not is_dead

func get_base_stat_value(stat_id: StringName, fallback: float = 0.0) -> float:
	if stat_id == &"move_speed":
		fallback = player_move_speed
	elif stat_id == &"attack_cooldown":
		fallback = 0.30
	elif stat_id == &"attack_speed_multiplier":
		fallback = 1.0
	if stats == null:
		return fallback
	return stats.get_value(stat_id, fallback)

func get_stat_value(stat_id: StringName, fallback: float = 0.0) -> float:
	var value := get_base_stat_value(stat_id, fallback)
	if buff_controller != null:
		value = buff_controller.get_stat_value(stat_id, value)
	if run_modifier_controller != null:
		value = run_modifier_controller.modify_stat_value(stat_id, value)
	return value

func ensure_run_modifier_controller() -> RunModifierController:
	if run_modifier_controller == null:
		run_modifier_controller = RunModifierControllerScript.new()
		_connect_run_modifier_controller_signals()
		run_modifier_controller.setup(self)
	return run_modifier_controller

func capture_player_runtime_state() -> Dictionary:
	var state := {}
	if run_modifier_controller != null and run_modifier_controller.has_active_effects():
		state["run_modifier_controller"] = run_modifier_controller
	var buff_snapshot := _duplicate_active_buffs()
	if not buff_snapshot.is_empty():
		state["buffs"] = buff_snapshot
	return state

func queue_player_runtime_state(runtime_state: Dictionary) -> void:
	_pending_player_runtime_state = runtime_state.duplicate(true)

func apply_player_runtime_state(runtime_state: Dictionary) -> void:
	if runtime_state.is_empty():
		return
	var transferred_run_modifier = runtime_state.get("run_modifier_controller")
	if transferred_run_modifier != null:
		_disconnect_run_modifier_controller_signals()
		run_modifier_controller = transferred_run_modifier
		_connect_run_modifier_controller_signals()
		run_modifier_controller.setup(self)
	var buff_snapshot: Array = runtime_state.get("buffs", [])
	for buff in buff_snapshot:
		add_buff(buff)
	if bool(runtime_state.get("mark_next_dash_as_detach", false)) and run_modifier_controller != null and run_modifier_controller.has_method("mark_next_dash_as_detach"):
		run_modifier_controller.call("mark_next_dash_as_detach")

func _apply_pending_player_runtime_state() -> void:
	if _pending_player_runtime_state.is_empty():
		return
	var runtime_state := _pending_player_runtime_state
	_pending_player_runtime_state = {}
	apply_player_runtime_state(runtime_state)

func _duplicate_active_buffs() -> Array:
	var snapshot: Array = []
	if buff_controller == null:
		return snapshot
	for buff in buff_controller.get_active_buffs():
		if buff == null or not buff.has_method("duplicate_effect"):
			continue
		var duplicated = buff.duplicate_effect()
		if duplicated != null:
			snapshot.append(duplicated)
	return snapshot

func add_buff(buff):
	if buff_controller == null:
		return null
	return buff_controller.add_buff(buff)

func remove_buff(buff) -> bool:
	if buff_controller == null:
		return false
	return buff_controller.remove_buff(buff)

func clear_buffs() -> void:
	if buff_controller != null:
		buff_controller.clear()

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
	if _amount > 0.0 and damage_number_spawner != null and damage_number_spawner.has_method("spawn_label"):
		var is_critical_hit := has_meta("incoming_damage_is_critical") and bool(get_meta("incoming_damage_is_critical"))
		damage_number_spawner.call("spawn_label", _amount, is_critical_hit)
	if _amount > 0.0:
		_play_hit_flash()
		_trigger_hit_camera_shake(source)
	if lifecycle_state != null:
		lifecycle_state.on_damaged(_amount, _current_health, _max_health, source)

func _trigger_hit_camera_shake(source: CharacterBody2D) -> void:
	if source == null or not is_instance_valid(source):
		return
	if source.has_meta("damage_is_ranged") and bool(source.get_meta("damage_is_ranged")):
		return
	if not bool(source.get("is_player_controlled")) or not source.has_method("_get_camera"):
		return
	var source_camera := source.call("_get_camera") as Camera2D
	if source_camera == null or not source_camera.enabled or not source_camera.has_method("trigger_hit_shake"):
		return
	source_camera.call("trigger_hit_shake", 1.0, 1.0)

func _play_hit_flash() -> void:
	var overlay := _ensure_hit_flash_overlay()
	if overlay == null:
		return
	_sync_hit_flash_overlay()
	overlay.visible = true
	overlay.self_modulate = Color(1.0, 1.0, 1.0, 0.9)
	if hit_flash_tween != null and hit_flash_tween.is_valid():
		hit_flash_tween.kill()
	hit_flash_tween = create_tween()
	hit_flash_tween.tween_property(overlay, "self_modulate:a", 0.0, 0.12)
	hit_flash_tween.finished.connect(func():
		if overlay != null and is_instance_valid(overlay):
			overlay.visible = false
	)

func _ensure_hit_flash_overlay() -> Sprite2D:
	var sprite := _find_self_sprite()
	if sprite == null:
		return null
	if hit_flash_overlay_sprite != null and is_instance_valid(hit_flash_overlay_sprite):
		if hit_flash_overlay_sprite.get_parent() == self:
			return hit_flash_overlay_sprite
		hit_flash_overlay_sprite.queue_free()
	hit_flash_overlay_sprite = Sprite2D.new()
	hit_flash_overlay_sprite.name = "HitFlashOverlay"
	hit_flash_overlay_sprite.visible = false
	hit_flash_overlay_sprite.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	hit_flash_overlay_sprite.z_as_relative = sprite.z_as_relative
	hit_flash_overlay_sprite.z_index = sprite.z_index + 1
	if hit_flash_overlay_material == null:
		hit_flash_overlay_material = ShaderMaterial.new()
		hit_flash_overlay_material.shader = HitFlashOverlayShader
	hit_flash_overlay_sprite.material = hit_flash_overlay_material
	add_child(hit_flash_overlay_sprite)
	_sync_hit_flash_overlay()
	return hit_flash_overlay_sprite

func _sync_hit_flash_overlay() -> void:
	var sprite := _find_self_sprite()
	var overlay := hit_flash_overlay_sprite
	if sprite == null or overlay == null or not is_instance_valid(overlay):
		return
	overlay.texture = sprite.texture
	overlay.hframes = sprite.hframes
	overlay.vframes = sprite.vframes
	overlay.frame = sprite.frame
	overlay.frame_coords = sprite.frame_coords
	overlay.flip_h = sprite.flip_h
	overlay.flip_v = sprite.flip_v
	overlay.position = sprite.position
	overlay.rotation = sprite.rotation
	overlay.scale = sprite.scale
	overlay.skew = sprite.skew
	overlay.offset = sprite.offset
	overlay.centered = sprite.centered
	overlay.region_enabled = sprite.region_enabled
	overlay.region_rect = sprite.region_rect
	overlay.region_filter_clip_enabled = sprite.region_filter_clip_enabled

func _clear_hit_flash_overlay() -> void:
	if hit_flash_tween != null and hit_flash_tween.is_valid():
		hit_flash_tween.kill()
	hit_flash_tween = null
	if hit_flash_overlay_sprite != null and is_instance_valid(hit_flash_overlay_sprite):
		hit_flash_overlay_sprite.queue_free()
	hit_flash_overlay_sprite = null

func _ensure_possession_combo_overlay() -> Sprite2D:
	var sprite := _find_self_sprite()
	if sprite == null:
		return null
	if possession_combo_overlay_sprite != null and is_instance_valid(possession_combo_overlay_sprite):
		if possession_combo_overlay_sprite.get_parent() == self:
			return possession_combo_overlay_sprite
		possession_combo_overlay_sprite.queue_free()
	possession_combo_overlay_sprite = Sprite2D.new()
	possession_combo_overlay_sprite.name = "PossessionComboOverlay"
	possession_combo_overlay_sprite.visible = false
	possession_combo_overlay_sprite.self_modulate = Color(1.0, 0.45, 0.45, 0.28)
	possession_combo_overlay_sprite.z_as_relative = sprite.z_as_relative
	possession_combo_overlay_sprite.z_index = sprite.z_index + 1
	add_child(possession_combo_overlay_sprite)
	return possession_combo_overlay_sprite

func _sync_possession_combo_overlay() -> void:
	var sprite := _find_self_sprite()
	if sprite == null or buff_controller == null or not buff_controller.has_buff(&"possession_combo_haste"):
		_clear_possession_combo_overlay()
		return
	var overlay := _ensure_possession_combo_overlay()
	if overlay == null:
		return
	overlay.texture = sprite.texture
	overlay.hframes = sprite.hframes
	overlay.vframes = sprite.vframes
	overlay.frame = sprite.frame
	overlay.frame_coords = sprite.frame_coords
	overlay.flip_h = sprite.flip_h
	overlay.flip_v = sprite.flip_v
	overlay.position = sprite.position
	overlay.rotation = sprite.rotation
	overlay.scale = sprite.scale
	overlay.skew = sprite.skew
	overlay.offset = sprite.offset
	overlay.centered = sprite.centered
	overlay.region_enabled = sprite.region_enabled
	overlay.region_rect = sprite.region_rect
	overlay.region_filter_clip_enabled = sprite.region_filter_clip_enabled
	overlay.visible = true

func _clear_possession_combo_overlay() -> void:
	if possession_combo_overlay_sprite != null and is_instance_valid(possession_combo_overlay_sprite):
		possession_combo_overlay_sprite.queue_free()
	possession_combo_overlay_sprite = null

func _on_died(_killer: CharacterBody2D) -> void:
	if lifecycle_state != null:
		lifecycle_state.on_died(_killer)

func _on_revive_timeout() -> void:
	if lifecycle_state != null:
		lifecycle_state.on_revive_timeout()

func revive(revive_in_place: bool = false) -> void:
	if lifecycle_state != null:
		lifecycle_state.revive(revive_in_place)

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

func lock_possession_input_for_finisher(duration: float) -> void:
	var lock_duration := maxf(0.0, duration)
	if lock_duration <= 0.0:
		return
	_possession_input_lock_count += 1
	var tree := get_tree()
	if tree == null:
		return
	var self_ref: WeakRef = weakref(self)
	var timer: SceneTreeTimer = tree.create_timer(lock_duration, true, false, true)
	timer.timeout.connect(func() -> void:
		var character: Node = self_ref.get_ref() as Node
		if character == null:
			return
		if character.has_method("_release_possession_input_lock"):
			character.call("_release_possession_input_lock")
	)

func is_possession_input_locked() -> bool:
	return _possession_input_lock_count > 0

func _release_possession_input_lock() -> void:
	_possession_input_lock_count = max(0, _possession_input_lock_count - 1)

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
	_sync_hit_flash_overlay()
	_sync_possession_combo_overlay()
	if dash_cooldown_left > 0.0:
		dash_cooldown_left = maxf(0.0, dash_cooldown_left - delta)
	if invincibility_time_left > 0.0:
		invincibility_time_left = maxf(0.0, invincibility_time_left - delta)
	if control_state != null:
		control_state.try_toggle_developer_mode()
	if interaction_state != null:
		interaction_state.process(delta)
	if buff_controller != null and not is_dead:
		buff_controller.update(delta)
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

func can_start_dash() -> bool:
	if not dash_enabled or not is_player_controlled or is_dead or is_hurt_playing:
		return false
	if dash_time_left > 0.0 or dash_cooldown_left > 0.0:
		return false
	if control_state != null:
		if control_state.is_player_input_blocked() or control_state.is_detach_blocking_movement() or control_state.is_developer_mode_active():
			return false
	if attack_module != null:
		if attack_module.has_method("is_busy") and attack_module.is_busy():
			return false
		if attack_module.has_method("can_move") and not attack_module.can_move():
			return false
	return true

func start_dash(direction: float) -> bool:
	if not can_start_dash():
		return false
	if is_zero_approx(direction):
		direction = get_facing_direction()
	_start_dash_state(Vector2(direction * dash_speed, 0.0), dash_duration, dash_cooldown, dash_invincibility_duration)
	return true

func finish_dash() -> void:
	var was_dashing := dash_time_left > 0.0 or dash_velocity != Vector2.ZERO
	var dash_end_position := global_position
	dash_time_left = 0.0
	dash_velocity = Vector2.ZERO
	if not is_dead:
		_restore_default_collision_state()
	stop_afterimage_effect()
	if was_dashing:
		dash_finished.emit(_dash_start_position, dash_end_position)

func get_facing_direction() -> float:
	var sprite := _find_self_sprite()
	if sprite != null and sprite.flip_h:
		return -1.0
	return 1.0

func start_forced_dash(dash_vector: Vector2, duration: float, invincibility_duration: float = -1.0) -> void:
	var i_frame_duration := invincibility_duration
	if i_frame_duration < 0.0:
		i_frame_duration = minf(duration, dash_invincibility_duration)
	_start_dash_state(dash_vector, duration, 0.0, i_frame_duration)

func start_invincibility(duration: float) -> void:
	invincibility_time_left = maxf(invincibility_time_left, maxf(0.0, duration))

func is_damage_invincible() -> bool:
	return invincibility_time_left > 0.0

func _start_dash_state(dash_vector: Vector2, duration: float, cooldown_duration: float, invincibility_duration: float) -> void:
	_dash_start_position = global_position
	dash_velocity = dash_vector
	dash_time_left = maxf(0.0, duration)
	dash_cooldown_left = maxf(dash_cooldown_left, cooldown_duration)
	velocity = dash_vector
	_set_locomotion_conditions(signf(dash_vector.x))
	_apply_dash_collision_mask()
	start_invincibility(invincibility_duration)
	start_afterimage_effect()

func _apply_dash_collision_mask() -> void:
	collision_layer = 0
	collision_mask = _default_collision_mask & WORLD_COLLISION_MASK

func apply_knockback_physics(delta: float) -> void:
	if control_state != null:
		control_state.apply_knockback_physics(delta)

func try_common_jump() -> void:
	if control_state != null:
		control_state.try_common_jump()

func get_player_move_speed() -> float:
	if control_state == null:
		return float(get_stat_value(&"move_speed", player_move_speed))
	return control_state.get_player_move_speed()

func get_developer_move_speed() -> float:
	if control_state == null:
		return float(get_stat_value(&"move_speed", player_move_speed)) * DEVELOPER_SPEED_MULTIPLIER
	return control_state.get_developer_move_speed()

func get_attack_cooldown(fallback: float = 0.30) -> float:
	return float(get_stat_value(&"attack_cooldown", fallback))

func get_attack_speed_multiplier(fallback: float = 1.0) -> float:
	return maxf(0.05, float(get_stat_value(&"attack_speed_multiplier", fallback)))

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

func _resolve_audio_manager() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var group_name := AudioManagerScript.AUDIO_MANAGER_GROUP
	var audio_manager := tree.get_first_node_in_group(group_name)
	if audio_manager != null:
		return audio_manager
	var current_scene := tree.current_scene
	if current_scene != null:
		audio_manager = current_scene.get_node_or_null("AudioManager")
		if audio_manager != null:
			return audio_manager
	return tree.root.get_node_or_null("AudioManager")

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
	if _should_collide_with_character_bodies():
		collision_mask |= _default_collision_layer

func _should_collide_with_character_bodies() -> bool:
	return is_player_controlled and (_force_player_body_collision or not start_player_controlled)

func set_force_player_body_collision(enabled: bool) -> void:
	_force_player_body_collision = enabled

func _on_corpse_cleanup_timeout() -> void:
	if lifecycle_state != null:
		lifecycle_state.on_corpse_cleanup_timeout()

func start_afterimage_effect() -> void:
	if not afterimage_enabled or _is_creating_afterimages or sprite_2d == null:
		return
	_is_creating_afterimages = true
	_create_afterimage()
	if afterimage_timer != null:
		afterimage_timer.start()

func stop_afterimage_effect() -> void:
	_is_creating_afterimages = false
	if afterimage_timer != null:
		afterimage_timer.stop()

func _create_afterimage() -> void:
	if not _is_creating_afterimages or sprite_2d == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	var pool := tree.root.get_node_or_null("VfxPool")
	if pool == null or not pool.has_method("play_afterimage"):
		return
	pool.call("play_afterimage", {
		"texture": sprite_2d.texture,
		"hframes": sprite_2d.hframes,
		"vframes": sprite_2d.vframes,
		"frame": sprite_2d.frame,
		"transform": self.global_transform,
		"flip_h": sprite_2d.flip_h,
		"offset": sprite_2d.offset,
		"centered": sprite_2d.centered,
		"color": afterimage_color,
		"duration": afterimage_duration,
		"final_scale": afterimage_final_scale,
	})

	# 如果效果仍在持续，再次启动计时器
	if _is_creating_afterimages and afterimage_timer != null:
		afterimage_timer.start()

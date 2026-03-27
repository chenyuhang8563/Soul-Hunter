extends CharacterBody2D

signal npc_interacted(interactor: CharacterBody2D)

const DIALOGUE_DEBUG_LOG_PATH := "res://docs/refactor/archer_dialogue_debug.log"

var ai_module: RefCounted = null
var attack_module: AttackModuleBase = null

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
	if ai_module != null and ai_module.has_method("force_stop"):
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

const ANIM_HURT := "hurt"
const ANIM_DEATH := "death"
const HintIconScene := preload("res://Scenes/icon.tscn")
const F_IconTexture := preload("res://Assets/Sprites/UI/F.png")
const E_IconTexture := preload("res://Assets/Sprites/UI/E.png")
const PossessionOutlineShader := preload("res://Shaders/possession_outline.gdshader")

const KNOCKBACK_VELOCITY := 140.0
const KNOCKBACK_DECAY := 490.0
const FALL_DEATH_Y := 500.0
const HAZARD_CHECK_DEPTH := 5.0
const DEVELOPER_SPEED_MULTIPLIER := 2.0

@onready var hp_bar: ProgressBar = get_node_or_null("HPBar")
@onready var posture_bar: ProgressBar = get_node_or_null("PostureBar")
@onready var animation_tree: AnimationTree = get_node_or_null("AnimationTree")
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
const CharacterUIPresenterScript := preload("res://Character/Common/character_ui_presenter.gd")

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

var _hazard_check_timer := 0.0
const HAZARD_CHECK_INTERVAL := 0.1
var _prompt_icon_update_timer := 0.0
const PROMPT_ICON_UPDATE_INTERVAL := 0.05
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
	_setup_health()
	add_to_group("possessable_character")
	set_player_controlled(start_player_controlled)
	
	var DetachModuleScript = preload("res://Character/Common/detach_module.gd")
	if DetachModuleScript != null:
		detach_module = DetachModuleScript.new()
		detach_module.setup(self)
		
	_on_character_ready()

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
	_get_ui_presenter().update_health(current_health, max_health)
	_update_possession_prompt_icon()

func apply_damage(amount: float, source: CharacterBody2D = null) -> void:
	if is_developer_mode_active():
		return
	health.apply_damage(amount, source)

func add_posture(amount: float) -> void:
	if is_dead:
		return
	current_posture = minf(max_posture, current_posture + amount)
	time_since_last_posture_increase = 0.0
	_get_ui_presenter().update_posture(current_posture, max_posture)

func is_posture_broken() -> bool:
	return current_posture >= max_posture

func heal(amount: float) -> void:
	health.heal(amount)

func is_alive() -> bool:
	return health.is_alive()

func get_hp_ratio() -> float:
	return health.get_hp_ratio()

func _on_damaged(_amount: float, _current_health: float, _max_health: float, source: CharacterBody2D) -> void:
	if is_dead:
		return
		
	if source != null:
		var direction := signf(global_position.x - source.global_position.x)
		if direction == 0.0:
			direction = 1.0 if randf() > 0.5 else -1.0
		knockback_velocity = direction * KNOCKBACK_VELOCITY
	else:
		knockback_velocity = 0.0
		
	if animation_player == null or not animation_player.has_animation(ANIM_HURT):
		return
	is_hurt_playing = true
	_on_enter_hurt()
	if animation_tree != null:
		animation_tree.active = false
	animation_player.play(ANIM_HURT)

func _on_died(_killer: CharacterBody2D) -> void:
	is_dead = true
	is_hurt_playing = false
	_clear_possessed_highlight()
	_clear_possession_prompt_icon()
	_clear_dialogue_prompt_icon()
	_set_corpse_collision_state()
	
	if hp_bar != null:
		hp_bar.visible = false
	if posture_bar != null:
		posture_bar.visible = false
		
	_on_enter_dead()
	if animation_tree != null:
		animation_tree.active = false
	if animation_player != null and animation_player.has_animation(ANIM_DEATH):
		animation_player.play(ANIM_DEATH)
	velocity = Vector2.ZERO
	if auto_revive and is_inside_tree():
		var timer := get_tree().create_timer(maxf(0.0, revive_delay))
		timer.timeout.connect(_on_revive_timeout)
	elif not remove_after_death_animation:
		_schedule_corpse_cleanup()

func _on_revive_timeout() -> void:
	if not is_inside_tree() or not is_dead:
		return
	revive()

func revive() -> void:
	if not is_dead:
		return
	is_dead = false
	remove_after_death_animation = false
	is_hurt_playing = false
	_restore_default_collision_state()
	velocity = Vector2.ZERO
	if revive_at_spawn:
		global_position = spawn_position
	if animation_tree != null:
		animation_tree.active = true
		
	if hp_bar != null:
		hp_bar.visible = true
	# Posture bar visibility is managed by update_posture, so we don't force show it here
	# unless we want it to flash or something, but standard behavior is hide when 0.
	
	_on_revived()
	health.setup(stats.max_health)
	current_posture = 0.0
	time_since_last_posture_increase = 0.0
	_get_ui_presenter().update_posture(current_posture, max_posture)
	_update_possession_prompt_icon()
	_update_possessed_highlight()

func set_player_controlled(controlled: bool) -> void:
	if is_player_controlled == controlled:
		return
	is_player_controlled = controlled
	if not controlled:
		_clear_possession_prompt_icon()
		var camera := _get_camera()
		if camera != null:
			camera.enabled = false
	_clear_possessed_highlight()
	if is_inside_tree():
		if controlled:
			add_to_group("player_controlled")
			var camera := _get_camera()
			if camera == null:
				camera = Camera2D.new()
				camera.name = "Camera2D"
				add_child(camera)
			camera.enabled = true
			camera.make_current()
			if SceneManager.has_signal("camera_changed"):
				SceneManager.camera_changed.emit(camera)
		else:
			remove_from_group("player_controlled")
	_update_possession_prompt_icon()
	_update_possessed_highlight()
	_on_control_mode_changed(controlled)

func _get_camera() -> Camera2D:
	for child in get_children():
		if child is Camera2D:
			return child as Camera2D
	return null

func try_manual_possession() -> void:
	_update_possession_prompt_icon()
	_update_possessed_highlight()
	if not is_player_controlled or is_dead:
		return
	if not InputMap.has_action("possess") or not Input.is_action_just_pressed("possess"):
		return
	var target := _find_nearby_possession_target()
	if target == null:
		return
	target.call("receive_possession_from", self)

func try_manual_detach(delta: float) -> void:
	if not is_player_controlled or is_dead:
		return
	# Prevent original Soldier from detaching
	if name.begins_with("Soldier") and self.get_script().resource_path.ends_with("soldier.gd"):
		return
	if detach_module != null:
		detach_module.update(delta)

func is_detach_blocking_movement() -> bool:
	if detach_module != null and detach_module.has_method("is_blocking_movement"):
		return detach_module.is_blocking_movement()
	return false

func _find_nearby_possession_target() -> CharacterBody2D:
	if not is_inside_tree():
		return null
	var best_target: CharacterBody2D
	var best_distance := possession_range
	for node in get_tree().get_nodes_in_group("possessable_character"):
		if node == self:
			continue
		if not (node is CharacterBody2D):
			continue
		var candidate := node as CharacterBody2D
		if not candidate.has_method("can_be_possessed_now") or not bool(candidate.call("can_be_possessed_now")):
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance <= best_distance:
			best_distance = distance
			best_target = candidate
	return best_target

func _update_possession_prompt_icon() -> void:
	var should_show_f = false
	var should_show_e = false
	
	var player_nodes := get_tree().get_nodes_in_group("player_controlled")
	if not is_player_controlled:
		for p in player_nodes:
			if p is CharacterBody2D:
				var dist = global_position.distance_to(p.global_position)
				if can_be_possessed_now() and dist <= possession_range:
					should_show_f = true
				if not is_dead and is_interactable_npc and dist <= dialogue_range:
					should_show_e = true

	# Handle F icon
	if should_show_f:
		possession_prompt_icon = _ensure_hint_icon(possession_prompt_icon, F_IconTexture)
	else:
		_clear_possession_prompt_icon()
			
	# Handle E icon (only show E if F is not shown to avoid overlap, or adjust position)
	if should_show_e and not should_show_f:
		dialogue_prompt_icon = _ensure_hint_icon(dialogue_prompt_icon, E_IconTexture)
	else:
		_clear_dialogue_prompt_icon()

func _find_nearby_dialogue_player() -> CharacterBody2D:
	if is_player_controlled or not is_interactable_npc or is_dead:
		return null

	for p in get_tree().get_nodes_in_group("player_controlled"):
		if p is CharacterBody2D:
			var player := p as CharacterBody2D
			if global_position.distance_to(player.global_position) <= dialogue_range:
				return player
	return null

func _append_dialogue_debug_log(message: String) -> void:
	var file_path := ProjectSettings.globalize_path(DIALOGUE_DEBUG_LOG_PATH)
	var file := FileAccess.open(file_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(message)
	file.close()

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
		var sprite = current_icon as Sprite2D
		if sprite == null:
			sprite = current_icon.get_node_or_null("Sprite2D")
		if sprite and sprite.texture != texture:
			sprite.texture = texture
			
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

func receive_possession_from(possessor: CharacterBody2D) -> bool:
	if possessor == null or possessor == self:
		return false
	if not can_be_possessed_now():
		return false
	if not possessor.has_method("is_player_character") or not bool(possessor.call("is_player_character")):
		return false
	if possessor.has_method("get_team_id") and int(possessor.call("get_team_id")) == team_id:
		return false
	if possessor.has_method("set_player_controlled"):
		possessor.call("set_player_controlled", false)
	if possessor.has_method("get_team_id"):
		team_id = int(possessor.call("get_team_id"))
	if is_dead:
		revive()
	set_player_controlled(true)

	var target_health := health.max_health * 0.75
	if health.current_health < target_health:
		var heal_amount := target_health - health.current_health
		health.heal(heal_amount)

	if possessor.has_method("consume_for_possession"):
		possessor.call("consume_for_possession")
	return true

func can_be_possessed_now() -> bool:
	if not can_be_possessed or is_player_controlled:
		return false
	if is_dead:
		return true
	return get_hp_ratio() <= possession_hp_threshold

func is_player_character() -> bool:
	return is_player_controlled

func get_team_id() -> int:
	return team_id

func _process(delta: float) -> void:
	try_toggle_developer_mode()
	_prompt_icon_update_timer += delta
	if _prompt_icon_update_timer >= PROMPT_ICON_UPDATE_INTERVAL:
		_update_possession_prompt_icon()
		_prompt_icon_update_timer = 0.0

	if InputMap.has_action("interact") and Input.is_action_just_pressed("interact"):
		if is_interactable_npc:
			_append_dialogue_debug_log("[character] interact pressed on NPC=%s" % name)
		var nearby_player := _find_nearby_dialogue_player()
		if nearby_player != null:
			_append_dialogue_debug_log("[character] npc_interacted emit npc=%s player=%s distance=%.2f" % [name, nearby_player.name, global_position.distance_to(nearby_player.global_position)])
			npc_interacted.emit(nearby_player)
		elif is_interactable_npc:
			_append_dialogue_debug_log("[character] no nearby player for npc=%s" % name)

	if is_dead:
		return

	_hazard_check_timer += delta
	if _hazard_check_timer >= HAZARD_CHECK_INTERVAL:
		_check_environment_hazards()
		_hazard_check_timer = 0.0

	_check_fall_death()

	if current_posture > 0.0:
		time_since_last_posture_increase += delta
		if time_since_last_posture_increase >= posture_recovery_delay:
			current_posture = maxf(0.0, current_posture - posture_recovery_rate * delta)
			_get_ui_presenter().update_posture(current_posture, max_posture)

func _check_environment_hazards() -> void:
	if not is_inside_tree():
		return
		
	var current_scene = get_tree().current_scene
	var tilemap: TileMapLayer = TileMapUtils.get_tilemap_from_scene(current_scene)
			
	if not tilemap:
		return
		
	var check_depth = HAZARD_CHECK_DEPTH
	var foot_position = global_position + Vector2(0, check_depth)
	
	var map_coord = tilemap.local_to_map(tilemap.to_local(foot_position))
	
	var tile_data = tilemap.get_cell_tile_data(map_coord)
	
	if tile_data and tile_data.get_custom_data("is_spike"):
		if self.name.contains("Slime") or self.is_in_group("immune_to_spikes"):
			return
			
		apply_damage(9999.0, null)

func _check_fall_death() -> void:
	if global_position.y > FALL_DEATH_Y:
		apply_damage(9999.0, null)

func apply_common_gravity(delta: float) -> void:
	if is_developer_mode_active():
		velocity.y = 0.0
		return
	if dash_time_left > 0.0:
		return # Disable gravity during dash
	if not is_on_floor():
		velocity.y += gravity * delta
	elif velocity.y > 0:
		velocity.y = 0

func apply_dash_physics(delta: float) -> bool:
	if dash_time_left > 0.0:
		dash_time_left -= delta
		velocity = dash_velocity
		return true
	return false

func apply_knockback_physics(delta: float) -> void:
	if knockback_velocity != 0.0:
		knockback_velocity = move_toward(knockback_velocity, 0.0, KNOCKBACK_DECAY * delta)
	velocity.x = knockback_velocity

func try_common_jump() -> void:
	if is_developer_mode_active():
		return
	if not is_player_controlled:
		return
	if is_detach_blocking_movement():
		return
	if InputMap.has_action("ui_accept") and Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = -jump_velocity

func get_player_move_speed() -> float:
	return player_move_speed

func get_developer_move_speed() -> float:
	return player_move_speed * DEVELOPER_SPEED_MULTIPLIER

func is_developer_mode_active() -> bool:
	return DeveloperMode.applies_to(self)

func try_toggle_developer_mode() -> void:
	if not is_player_controlled:
		return
	if not InputMap.has_action("developer_mode_toggle"):
		return
	if Input.is_action_just_pressed("developer_mode_toggle"):
		DeveloperMode.toggle()

func apply_developer_flight_movement() -> bool:
	if not is_developer_mode_active():
		return false

	var input_x := Input.get_axis("ui_left", "ui_right")
	var input_y := Input.get_axis("ui_up", "ui_down")
	var move_speed := get_developer_move_speed()

	velocity.x = input_x * move_speed
	velocity.y = input_y * move_speed

	var sprite := _find_self_sprite()
	if sprite != null and input_x != 0.0:
		sprite.flip_h = input_x < 0.0

	_set_locomotion_conditions(input_x)
	return true

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == ANIM_DEATH and is_dead and remove_after_death_animation:
		queue_free()
		return
	if is_dead:
		return
	if anim_name == ANIM_HURT:
		is_hurt_playing = false
		if animation_tree != null:
			animation_tree.active = true
		_on_exit_hurt()

func consume_for_possession() -> void:
	if is_dead:
		return
	remove_after_death_animation = true
	auto_revive = false
	is_dead = true
	is_hurt_playing = false
	_clear_possessed_highlight()
	_clear_possession_prompt_icon()
	set_player_controlled(false)
	_on_enter_dead()
	if animation_tree != null:
		animation_tree.active = false
	velocity = Vector2.ZERO
	if animation_player == null or not animation_player.has_animation(ANIM_DEATH):
		queue_free()
		return
	animation_player.play(ANIM_DEATH)

func _on_enter_hurt() -> void:
	pass

func _on_exit_hurt() -> void:
	pass

func _on_enter_dead() -> void:
	pass

func _on_revived() -> void:
	pass

func _set_corpse_collision_state() -> void:
	collision_layer = 0
	collision_mask = 1

func _restore_default_collision_state() -> void:
	collision_layer = _default_collision_layer
	collision_mask = _default_collision_mask

func _schedule_corpse_cleanup() -> void:
	if corpse_cleanup_delay <= 0.0 or not is_inside_tree():
		return
	var timer := get_tree().create_timer(corpse_cleanup_delay)
	timer.timeout.connect(_on_corpse_cleanup_timeout)

func _on_corpse_cleanup_timeout() -> void:
	if not is_inside_tree() or not is_dead or is_player_controlled or remove_after_death_animation:
		return
	_respawn_from_corpse()

func _respawn_from_corpse() -> void:
	var parent := get_parent()
	if parent == null:
		queue_free()
		return
	if _respawn_scene_path.is_empty():
		queue_free()
		return
	var packed_scene := load(_respawn_scene_path) as PackedScene
	if packed_scene == null:
		queue_free()
		return
	var respawned := packed_scene.instantiate()
	if respawned is Node2D:
		(respawned as Node2D).global_position = spawn_position
	parent.add_child(respawned)
	queue_free()


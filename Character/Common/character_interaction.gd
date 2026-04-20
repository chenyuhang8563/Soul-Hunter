class_name CharacterInteraction
extends RefCounted

const HintIconScene := preload("res://Scenes/icon.tscn")
const F_IconTexture := preload("res://Assets/Sprites/UI/F.png")
const E_IconTexture := preload("res://Assets/Sprites/UI/E.png")
const InteractionTargetScript := preload("res://Character/Common/interaction_target.gd")
const POSSESSION_INPUT_FRAME_META := &"_possession_input_frame"

var owner
var _prompt_icon_update_timer := 0.0
var _requested_interaction_prompt := false
var _current_interaction_target: Node = null

func setup(character) -> void:
	owner = character

func on_ready() -> void:
	if owner.is_interactable_npc:
		owner.add_to_group("interaction_target")

func on_control_mode_changed(controlled: bool) -> void:
	if controlled:
		_requested_interaction_prompt = false
		_refresh_dialogue_prompt_icon()
		return
	_clear_current_interaction_target()

func process(delta: float) -> void:
	_prompt_icon_update_timer += delta
	if _prompt_icon_update_timer >= owner.PROMPT_ICON_UPDATE_INTERVAL:
		_update_possession_prompt_icon()
		if owner.is_player_controlled:
			_update_player_interaction_target()
		_prompt_icon_update_timer = 0.0
	if owner.is_player_controlled and not DialogueManager.is_dialogue_active():
		_try_interact_with_current_target()
	elif owner.is_player_controlled:
		_clear_current_interaction_target()

func try_manual_possession() -> void:
	_update_possession_prompt_icon()
	owner._update_possessed_highlight()
	if not owner.is_player_controlled or owner.is_dead or DialogueManager.is_dialogue_active():
		return
	if owner.has_method("is_possession_input_locked") and bool(owner.call("is_possession_input_locked")):
		return
	if _is_possession_input_consumed_this_frame():
		return
	if not InputMap.has_action("possess") or not Input.is_action_just_pressed("possess"):
		return
	var target := _find_nearby_possession_target()
	if target == null:
		return
	if bool(target.call("receive_possession_from", owner)):
		_mark_possession_input_consumed_for_current_frame()

func receive_possession_from(possessor: CharacterBody2D) -> bool:
	if possessor == null or possessor == owner:
		return false
	if not can_be_possessed_now():
		return false
	if not possessor.has_method("is_player_character") or not bool(possessor.call("is_player_character")):
		return false
	if possessor.has_method("get_team_id") and int(possessor.call("get_team_id")) == owner.team_id:
		return false
	var runtime_state: Dictionary = {}
	if possessor.has_method("capture_player_runtime_state"):
		runtime_state = possessor.call("capture_player_runtime_state")
	var possessor_team_id: int = owner.team_id
	if possessor.has_method("get_team_id"):
		possessor_team_id = int(possessor.call("get_team_id"))
	if possessor.has_method("set_player_controlled"):
		possessor.call("set_player_controlled", false)
	owner.team_id = possessor_team_id
	if owner.is_dead:
		owner.revive(true)
	if owner.has_method("apply_player_runtime_state"):
		owner.call("apply_player_runtime_state", runtime_state)
	if owner.has_method("set_force_player_body_collision"):
		owner.call("set_force_player_body_collision", true)
	owner.set_player_controlled(true)
	var target_health: float = float(owner.health.max_health) * 0.75
	if owner.health.current_health < target_health:
		owner.health.heal(target_health - owner.health.current_health)
	var run_modifier = owner.get("run_modifier_controller")
	if run_modifier != null and run_modifier.has_method("record_possession"):
		run_modifier.call("record_possession")
	if possessor.has_method("consume_for_possession"):
		possessor.call("consume_for_possession")
	return true

func can_be_possessed_now() -> bool:
	if not owner.can_be_possessed or owner.is_player_controlled:
		return false
	if owner.is_dead:
		return true
	return owner.get_hp_ratio() <= owner.possession_hp_threshold

func can_interact(interactor: CharacterBody2D) -> bool:
	if not owner.is_interactable_npc or owner.is_player_controlled or owner.is_dead:
		return false
	if DialogueManager.is_dialogue_active():
		return false
	if not is_instance_valid(interactor):
		return false
	return owner.global_position.distance_to(interactor.global_position) <= owner.dialogue_range

func interact(interactor: CharacterBody2D) -> void:
	if can_interact(interactor):
		owner.npc_interacted.emit(interactor)

func set_interaction_prompt_visible(visible: bool) -> void:
	_requested_interaction_prompt = visible
	_refresh_dialogue_prompt_icon()

func _find_nearby_possession_target() -> CharacterBody2D:
	if not owner.is_inside_tree():
		return null
	var best_target: CharacterBody2D
	var best_distance: float = float(owner.possession_range)
	for node in owner.get_tree().get_nodes_in_group("possessable_character"):
		if node == owner or not (node is CharacterBody2D):
			continue
		var candidate: CharacterBody2D = node as CharacterBody2D
		if not candidate.has_method("can_be_possessed_now") or not bool(candidate.call("can_be_possessed_now")):
			continue
		var distance: float = owner.global_position.distance_to(candidate.global_position)
		if distance <= best_distance:
			best_distance = distance
			best_target = candidate
	return best_target

func _update_possession_prompt_icon() -> void:
	var should_show_f := false
	if not owner.is_player_controlled:
		for player in owner.get_tree().get_nodes_in_group("player_controlled"):
			if player is CharacterBody2D:
				var player_character: CharacterBody2D = player as CharacterBody2D
				var dist: float = owner.global_position.distance_to(player_character.global_position)
				if can_be_possessed_now() and dist <= owner.possession_range:
					should_show_f = true
					break
	if should_show_f:
		owner.possession_prompt_icon = owner._ensure_hint_icon(owner.possession_prompt_icon, F_IconTexture)
	else:
		owner._clear_possession_prompt_icon()
	_refresh_dialogue_prompt_icon()

func _refresh_dialogue_prompt_icon() -> void:
	var should_show_e: bool = _requested_interaction_prompt and owner.is_interactable_npc and not owner.is_player_controlled and not owner.is_dead
	if should_show_e and owner.possession_prompt_icon == null:
		owner.dialogue_prompt_icon = owner._ensure_hint_icon(owner.dialogue_prompt_icon, E_IconTexture)
	else:
		owner._clear_dialogue_prompt_icon()

func _update_player_interaction_target() -> void:
	if owner.is_dead or DialogueManager.is_dialogue_active():
		_clear_current_interaction_target()
		return
	var nearest_target: Node = null
	var best_distance: float = INF
	for node in owner.get_tree().get_nodes_in_group("interaction_target"):
		if node == owner or not InteractionTargetScript.is_valid_target(node):
			continue
		if not bool(node.call("can_interact", owner)):
			continue
		if not (node is Node2D):
			continue
		var target_node: Node2D = node as Node2D
		var distance: float = owner.global_position.distance_to(target_node.global_position)
		if distance < best_distance:
			best_distance = distance
			nearest_target = node
	if nearest_target == _current_interaction_target:
		return
	if is_instance_valid(_current_interaction_target) and _current_interaction_target.has_method("set_interaction_prompt_visible"):
		_current_interaction_target.call("set_interaction_prompt_visible", false)
	_current_interaction_target = nearest_target
	if is_instance_valid(_current_interaction_target) and _current_interaction_target.has_method("set_interaction_prompt_visible"):
		_current_interaction_target.call("set_interaction_prompt_visible", true)

func _clear_current_interaction_target() -> void:
	if is_instance_valid(_current_interaction_target) and _current_interaction_target.has_method("set_interaction_prompt_visible"):
		_current_interaction_target.call("set_interaction_prompt_visible", false)
	_current_interaction_target = null

func _try_interact_with_current_target() -> void:
	if _current_interaction_target == null or not is_instance_valid(_current_interaction_target):
		return
	if not InputMap.has_action("interact") or not Input.is_action_just_pressed("interact"):
		return
	if _current_interaction_target.has_method("interact"):
		_current_interaction_target.call("interact", owner)

func _is_possession_input_consumed_this_frame() -> bool:
	if owner == null or not owner.is_inside_tree():
		return false
	var tree: SceneTree = owner.get_tree()
	if tree == null:
		return false
	return int(tree.get_meta(POSSESSION_INPUT_FRAME_META, -1)) == Engine.get_physics_frames()

func _mark_possession_input_consumed_for_current_frame() -> void:
	if owner == null or not owner.is_inside_tree():
		return
	var tree: SceneTree = owner.get_tree()
	if tree == null:
		return
	tree.set_meta(POSSESSION_INPUT_FRAME_META, Engine.get_physics_frames())

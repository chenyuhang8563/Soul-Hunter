extends Node2D

enum LevelState {
	INTRO,
	TALKING_TO_ARCHER,
	FIND_KEY,
	DOOR_OPENING,
	REACH_EXIT,
	COMPLETED
}

var dialogue_loader = preload("res://Global/dialogue_data_loader.gd").new()

const CAM_OFFSET := 9.0
const INTERACTION_DISTANCE := 40.0
const EXIT_CAM_PADDING := 24.0
const ARCHER_DIALOGUE_PATH := "res://Data/Dialogues/archer_dialogue.json"
const DIALOGUE_DEBUG_LOG_PATH := "res://docs/refactor/archer_dialogue_debug.log"
const LEVEL_1_TASK_SET := preload("res://Data/Tasks/level_1_task_set.tres")
const LEVEL_1_TASK_SESSION_ID: StringName = &"level_1"
const TASK_FACT_ARCHER_DIALOGUE_ACTIVE: StringName = &"level_1.archer_dialogue_active"
const TASK_FACT_ARCHER_DIALOGUE_FINISHED: StringName = &"level_1.archer_dialogue_finished"
const TASK_FACT_KEY_COLLECTED: StringName = &"level_1.key_collected"
const TASK_FACT_DOOR_OPENED: StringName = &"level_1.door_opened"
const TASK_FACT_LEVEL_FINISHED: StringName = &"level_1.level_finished"

@export var player_character: CharacterBody2D
@export var archer: CharacterBody2D

@onready var door: StaticBody2D = %SceneDoor
@onready var level_finish_area: Area2D = %LevelFinishArea

@export_file("*.tscn") var next_scene_path: String = "res://Scenes/test.tscn"
@export var right_cam_limit: float = 0.0

signal level_finished

var current_state: LevelState = LevelState.INTRO
var has_archer_dialogue_finished := false
var has_key := false
var is_exit_unlocked := false
var is_archer_dialogue_active := false
var locked_cam_limit := 0.0
var unlocked_cam_limit := 0.0

func _ready() -> void:
	_resolve_scene_references()
	_reset_dialogue_debug_log()
	if is_instance_valid(door):
		locked_cam_limit = door.global_position.x + CAM_OFFSET
		right_cam_limit = locked_cam_limit
	if is_instance_valid(level_finish_area):
		unlocked_cam_limit = level_finish_area.global_position.x + EXIT_CAM_PADDING

	_lock_exit()
	_start_task_session()
	_connect_runtime_signals()
	_apply_camera_limit_to_current_player()
	_append_dialogue_debug_log("[level_1] ready archer=%s player=%s" % [str(archer), str(player_character)])

func _resolve_scene_references() -> void:
	if not is_instance_valid(player_character):
		player_character = get_node_or_null("Characters/Soldier") as CharacterBody2D
	if not is_instance_valid(archer):
		archer = get_node_or_null("Characters/Archer") as CharacterBody2D

func _connect_runtime_signals() -> void:
	if not SceneManager.camera_changed.is_connected(_on_camera_changed):
		SceneManager.camera_changed.connect(_on_camera_changed)
	if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	if is_instance_valid(archer):
		var archer_interacted_callable := Callable(self, "_on_archer_interacted")
		if archer.has_signal("npc_interacted") and not archer.is_connected("npc_interacted", archer_interacted_callable):
			archer.connect("npc_interacted", archer_interacted_callable)
			_append_dialogue_debug_log("[level_1] connected archer npc_interacted")
	if is_instance_valid(door):
		var door_opened_callable := Callable(self, "_on_door_opened")
		if door.has_signal("door_opened") and not door.is_connected("door_opened", door_opened_callable):
			door.connect("door_opened", door_opened_callable)
	var tree := get_tree()
	if tree != null and not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)

func _on_camera_changed(new_camera: Camera2D) -> void:
	var camera_owner := new_camera.get_parent()
	if camera_owner is CharacterBody2D:
		player_character = camera_owner
		_append_dialogue_debug_log("[level_1] camera_changed new player=%s" % player_character.name)
	_apply_camera_limit(new_camera)

func _exit_tree() -> void:
	if SceneManager.camera_changed.is_connected(_on_camera_changed):
		SceneManager.camera_changed.disconnect(_on_camera_changed)
	if DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(_on_dialogue_ended)
	if is_instance_valid(archer):
		var archer_interacted_callable := Callable(self, "_on_archer_interacted")
		if archer.has_signal("npc_interacted") and archer.is_connected("npc_interacted", archer_interacted_callable):
			archer.disconnect("npc_interacted", archer_interacted_callable)
	if is_instance_valid(door):
		var door_opened_callable := Callable(self, "_on_door_opened")
		if door.has_signal("door_opened") and door.is_connected("door_opened", door_opened_callable):
			door.disconnect("door_opened", door_opened_callable)
	var tree := get_tree()
	if tree != null and tree.node_added.is_connected(_on_node_added):
		tree.node_added.disconnect(_on_node_added)
	TaskManager.end_session(LEVEL_1_TASK_SESSION_ID)

func _on_level_finish_area_body_entered(body: Node2D) -> void:
	if not _can_finish_level(body):
		return

	_set_level_state(LevelState.COMPLETED)
	_publish_task_fact(TASK_FACT_LEVEL_FINISHED, true)
	level_finished.emit()
	if next_scene_path:
		SceneManager.change_scene(next_scene_path)

func _unhandled_input(event: InputEvent) -> void:
	if event == null or not event.is_action_pressed("interact") or event.is_echo():
		return

	_try_start_archer_dialogue()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		_try_start_archer_dialogue()

func _try_start_archer_dialogue() -> void:
	var current_player := _get_current_player_character()
	_append_dialogue_debug_log("[level_1] try_start via input player=%s" % [current_player.name if current_player != null else "null"])
	if _can_start_archer_dialogue(current_player):
		_start_archer_dialogue_with_player(current_player)

func _can_start_archer_dialogue(current_player: CharacterBody2D = null) -> bool:
	if current_state == LevelState.COMPLETED or is_archer_dialogue_active:
		_append_dialogue_debug_log("[level_1] can_start=false completed_or_active state=%s active=%s" % [str(current_state), str(is_archer_dialogue_active)])
		return false
	if DialogueManager.current_node_id != "":
		_append_dialogue_debug_log("[level_1] can_start=false dialogue already running node=%s" % DialogueManager.current_node_id)
		return false

	if current_player == null:
		current_player = _get_current_player_character()
	if not is_instance_valid(current_player) or not is_instance_valid(archer):
		_append_dialogue_debug_log("[level_1] can_start=false invalid player or archer")
		return false

	var distance := current_player.global_position.distance_to(archer.global_position)
	var can_start := distance <= INTERACTION_DISTANCE
	_append_dialogue_debug_log("[level_1] can_start player=%s archer=%s distance=%.2f result=%s" % [current_player.name, archer.name, distance, str(can_start)])
	return can_start

func _start_archer_dialogue_with_player(current_player: CharacterBody2D) -> void:
	var sprite := archer.get_node_or_null("Sprite2D") as Sprite2D
	if not is_instance_valid(current_player) or sprite == null:
		_append_dialogue_debug_log("[level_1] start_dialogue aborted invalid player or sprite")
		return

	var atlas = DialogueManager.extract_avatar_from_sprite(sprite)
	if current_player.global_position.x < archer.global_position.x:
		sprite.flip_h = true
	else:
		sprite.flip_h = false

	var dialogue_data = dialogue_loader.load_dialogue(ARCHER_DIALOGUE_PATH, atlas)
	if dialogue_data.is_empty():
		push_error("Failed to load archer dialogue!")
		_append_dialogue_debug_log("[level_1] dialogue data empty")
		return

	is_archer_dialogue_active = true
	_set_level_state(LevelState.TALKING_TO_ARCHER)
	_publish_task_fact(TASK_FACT_ARCHER_DIALOGUE_ACTIVE, true)
	_append_dialogue_debug_log("[level_1] calling DialogueManager.start_dialogue")
	DialogueManager.start_dialogue(dialogue_data)

func _on_archer_interacted(interactor: CharacterBody2D) -> void:
	_append_dialogue_debug_log("[level_1] received npc_interacted from archer interactor=%s" % [interactor.name if interactor != null else "null"])
	if _can_start_archer_dialogue(interactor):
		_start_archer_dialogue_with_player(interactor)

func _on_dialogue_ended() -> void:
	if not is_archer_dialogue_active:
		return

	is_archer_dialogue_active = false
	has_archer_dialogue_finished = true
	_publish_task_fact(TASK_FACT_ARCHER_DIALOGUE_ACTIVE, false)
	_publish_task_fact(TASK_FACT_ARCHER_DIALOGUE_FINISHED, true)

	if is_exit_unlocked:
		_set_level_state(LevelState.REACH_EXIT)
	elif has_key:
		_set_level_state(LevelState.DOOR_OPENING)
	else:
		_set_level_state(LevelState.FIND_KEY)

func _on_key_collected() -> void:
	has_key = true
	_publish_task_fact(TASK_FACT_KEY_COLLECTED, true)
	if is_exit_unlocked:
		_set_level_state(LevelState.REACH_EXIT)
		return

	_set_level_state(LevelState.DOOR_OPENING)
	if is_instance_valid(door) and door.has_method("open_door"):
		door.call("open_door")

func _on_door_opened() -> void:
	is_exit_unlocked = true
	_publish_task_fact(TASK_FACT_DOOR_OPENED, true)
	_set_level_state(LevelState.REACH_EXIT)

func _on_node_added(node: Node) -> void:
	_try_connect_key_signal(node)

func _try_connect_key_signal(node: Node) -> void:
	if node == null or not node.has_signal("key_collected"):
		return

	var key_collected_callable := Callable(self, "_on_key_collected")
	if not node.is_connected("key_collected", key_collected_callable):
		node.connect("key_collected", key_collected_callable)

func _set_level_state(next_state: LevelState) -> void:
	if current_state == next_state:
		return

	current_state = next_state
	_apply_state_side_effects()

func _apply_state_side_effects() -> void:
	match current_state:
		LevelState.INTRO, LevelState.TALKING_TO_ARCHER, LevelState.FIND_KEY, LevelState.DOOR_OPENING:
			if locked_cam_limit > 0.0:
				right_cam_limit = locked_cam_limit
		LevelState.REACH_EXIT:
			_unlock_exit()
			if unlocked_cam_limit > 0.0:
				right_cam_limit = unlocked_cam_limit
		LevelState.COMPLETED:
			pass

	_apply_camera_limit_to_current_player()

func _lock_exit() -> void:
	is_exit_unlocked = false
	if is_instance_valid(level_finish_area):
		level_finish_area.monitoring = false

func _unlock_exit() -> void:
	is_exit_unlocked = true
	if is_instance_valid(level_finish_area):
		level_finish_area.monitoring = true

func _apply_camera_limit_to_current_player() -> void:
	var current_player := _get_current_player_character()
	if current_player == null:
		return

	var cam := current_player.get_node_or_null("Camera2D") as Camera2D
	_apply_camera_limit(cam)

func _apply_camera_limit(camera: Camera2D) -> void:
	if right_cam_limit > 0.0 and is_instance_valid(camera):
		camera.limit_right = int(right_cam_limit)

func _get_current_player_character() -> CharacterBody2D:
	var tree := get_tree()
	if tree == null:
		return player_character if is_instance_valid(player_character) else null

	if is_instance_valid(player_character) and player_character.is_in_group("player_controlled"):
		var current_camera := player_character.get_node_or_null("Camera2D") as Camera2D
		if current_camera != null and current_camera.enabled:
			return player_character

	var fallback: CharacterBody2D = player_character if is_instance_valid(player_character) and player_character.is_in_group("player_controlled") else null
	for node in tree.get_nodes_in_group("player_controlled"):
		if node is CharacterBody2D:
			var candidate := node as CharacterBody2D
			var candidate_camera := candidate.get_node_or_null("Camera2D") as Camera2D
			if candidate_camera != null and candidate_camera.enabled:
				player_character = candidate
				return candidate
			if fallback == null:
				fallback = candidate

	player_character = fallback
	return fallback

func _can_finish_level(body: Node2D) -> bool:
	return is_exit_unlocked and current_state != LevelState.COMPLETED and body.is_in_group("player_controlled")

func _reset_dialogue_debug_log() -> void:
	var file_path := ProjectSettings.globalize_path(DIALOGUE_DEBUG_LOG_PATH)
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_line("=== Archer Dialogue Debug ===")
	file.close()

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

func _start_task_session() -> void:
	TaskManager.begin_session(LEVEL_1_TASK_SET, LEVEL_1_TASK_SESSION_ID)
	_publish_task_fact(TASK_FACT_ARCHER_DIALOGUE_ACTIVE, false)
	_publish_task_fact(TASK_FACT_ARCHER_DIALOGUE_FINISHED, has_archer_dialogue_finished)
	_publish_task_fact(TASK_FACT_KEY_COLLECTED, has_key)
	_publish_task_fact(TASK_FACT_DOOR_OPENED, is_exit_unlocked)
	_publish_task_fact(TASK_FACT_LEVEL_FINISHED, current_state == LevelState.COMPLETED)

func _publish_task_fact(fact_id: StringName, value: Variant) -> void:
	TaskEventBus.publish_fact(fact_id, value)

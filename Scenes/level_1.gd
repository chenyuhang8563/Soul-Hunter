extends Node2D

var dialogue_loader = preload("res://Global/dialogue_data_loader.gd").new()

# 摄像机和交互相关常量
const CAM_OFFSET := 9.0
const INTERACTION_DISTANCE := 40.0

# 依赖注入：在编辑器中指定玩家角色和NPC
@export var player_character: CharacterBody2D
@export var archer: CharacterBody2D

@onready var door : StaticBody2D = %SceneDoor
@onready var level_finish_area : Area2D = %LevelFinishArea

@export_file("*.tscn") var next_scene_path: String = "res://Scenes/test.tscn"

@export var right_cam_limit: float = 0.0

signal level_finished

func _ready() -> void:
	right_cam_limit = door.position.x + CAM_OFFSET 
	# 设置初始的摄像机限制
	if right_cam_limit > 0.0 and is_instance_valid(player_character):
		var cam = player_character.get_node_or_null("Camera2D")
		if cam:
			cam.limit_right = int(right_cam_limit)
			
	# 监听附身等操作引起的摄像机切换
	SceneManager.camera_changed.connect(_on_camera_changed)

func _on_camera_changed(new_camera: Camera2D) -> void:
	if right_cam_limit > 0.0 and is_instance_valid(new_camera):
		new_camera.limit_right = int(right_cam_limit)

func _exit_tree() -> void:
	# 断开 SceneManager 信号，防止内存泄漏
	if SceneManager.camera_changed.is_connected(_on_camera_changed):
		SceneManager.camera_changed.disconnect(_on_camera_changed)

func _on_level_finish_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_controlled"):
		level_finished.emit()
		# 使用导出配置的场景路径进行跳转
		if next_scene_path:
			SceneManager.change_scene(next_scene_path)


func _process(_delta):
	# If a dialogue is currently running, ignore further inputs for triggering
	if DialogueManager.current_node_id != "":
		return
		
	if Input.is_action_just_pressed("interact"):
		if is_instance_valid(player_character) and is_instance_valid(archer):
			var dist = player_character.global_position.distance_to(archer.global_position)
			if dist <= INTERACTION_DISTANCE:
				_start_archer_dialogue()

func _start_archer_dialogue():
	var sprite = archer.get_node("Sprite2D")
	var atlas = DialogueManager.extract_avatar_from_sprite(sprite)
	
	# Make NPC face the player
	if player_character.global_position.x < archer.global_position.x:
		sprite.flip_h = true
	else:
		sprite.flip_h = false
	
	var dialogue_data = dialogue_loader.load_dialogue("res://Data/Dialogues/archer_dialogue.json", atlas)
	
	if dialogue_data.is_empty():
		push_error("Failed to load archer dialogue!")
		return
	
	DialogueManager.start_dialogue(dialogue_data)

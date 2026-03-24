extends CanvasLayer

signal camera_changed(new_camera: Camera2D)

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var color_rect: ColorRect = $ColorRect

var is_transitioning := false

func _ready() -> void:
	# 初始状态透明
	color_rect.modulate.a = 0.0

func change_scene(target_scene_path: String) -> void:
	if is_transitioning:
		return
	
	# 检查场景文件是否存在
	if not ResourceLoader.exists(target_scene_path):
		push_error("Scene file not found: " + target_scene_path)
		return
	
	is_transitioning = true
	
	# 1. 淡出（变黑）
	animation_player.play("fade_out")
	await animation_player.animation_finished
	
	# 2. 切换场景
	var error = get_tree().change_scene_to_file(target_scene_path)
	if error != OK:
		push_error("Failed to change scene to: " + target_scene_path + " (error code: " + str(error) + ")")
		is_transitioning = false
		return
	
	# 等待一帧，确保场景加载完毕
	await get_tree().process_frame
	
	# 3. 淡入（变透明）
	animation_player.play("fade_in")
	await animation_player.animation_finished
	
	is_transitioning = false

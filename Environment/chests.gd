extends AnimatedSprite2D

const HintIconScene := preload("res://Scenes/icon.tscn")
const E_IconTexture := preload("res://Assets/Sprites/UI/E.png")
const KeyScene := preload("res://Environment/scenes_key.tscn")

var prompt_icon: Node2D
var is_opened := false
var interaction_range := 40.0

func _ready() -> void:
	# 确保初始时停止播放并停留在第一帧
	stop()
	frame = 0

func _process(_delta: float) -> void:
	if is_opened:
		return
		
	var should_show_e = false
	var player_nodes = get_tree().get_nodes_in_group("player_controlled")
	for p in player_nodes:
		if p is Node2D:
			if global_position.distance_to(p.global_position) <= interaction_range:
				should_show_e = true
				break
				
	if should_show_e:
		if prompt_icon == null:
			prompt_icon = HintIconScene.instantiate() as Node2D
			var sprite = prompt_icon as Sprite2D
			if sprite == null:
				sprite = prompt_icon.get_node_or_null("Sprite2D")
			if sprite:
				sprite.texture = E_IconTexture
			add_child(prompt_icon)
		# 将图标显示在箱子上方
		prompt_icon.position = Vector2(-8, -12)
		
		if Input.is_action_just_pressed("interact"):
			open_chest()
	else:
		_clear_prompt_icon()

func _clear_prompt_icon() -> void:
	if prompt_icon != null:
		if is_instance_valid(prompt_icon):
			prompt_icon.queue_free()
		prompt_icon = null

func open_chest() -> void:
	is_opened = true
	_clear_prompt_icon()
	
	# 确保动画不循环
	if sprite_frames and sprite_frames.has_animation("open"):
		sprite_frames.set_animation_loop("open", false)
		
	play("open")
	
	# 等待动画播放完毕
	await animation_finished
	
	# 生成钥匙并弹出
	var key_instance = KeyScene.instantiate()
	get_parent().add_child(key_instance)
	if key_instance.has_method("jump_out"):
		key_instance.jump_out(global_position)
	else:
		key_instance.global_position = global_position
	
	# 渐变消失，持续 1.0 秒，然后销毁节点
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(queue_free)

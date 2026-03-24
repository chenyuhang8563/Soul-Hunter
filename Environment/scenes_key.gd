extends AnimatedSprite2D

var pickup_range := 30.0
var can_pick_up := false

func _ready() -> void:
	play("default")

func jump_out(start_pos: Vector2) -> void:
	global_position = start_pos
	
	var jump_height := 20.0
	var jump_distance := randf_range(-20.0, 20.0)
	
	var tween = create_tween()
	
	# 上升阶段
	tween.tween_property(self, "global_position:y", start_pos.y - jump_height, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "global_position:x", start_pos.x + jump_distance / 2.0, 0.25).set_trans(Tween.TRANS_LINEAR)
	
	# 下落阶段
	tween.chain().tween_property(self, "global_position:y", start_pos.y + 10.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "global_position:x", start_pos.x + jump_distance, 0.25).set_trans(Tween.TRANS_LINEAR)
	
	await tween.finished
	can_pick_up = true

func _process(_delta: float) -> void:
	if not can_pick_up:
		return
		
	var player_nodes = get_tree().get_nodes_in_group("player_controlled")
	for p in player_nodes:
		if p is Node2D:
			if global_position.distance_to(p.global_position) <= pickup_range:
				pick_up()
				break

func pick_up() -> void:
	can_pick_up = false
	print("捡起钥匙: ScenesKey")
	
	# 通知所有的门播放开门动画
	get_tree().call_group("doors", "open_door")
	
	# 可以在这里添加捡起钥匙的特效、音效，或者通知玩家背包增加了钥匙
	
	# 渐变消失后销毁
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

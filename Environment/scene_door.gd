extends StaticBody2D

signal door_opened

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# 加入组，以便钥匙被捡起时能通知到门
	add_to_group("doors")
	
	# 确保开门动画播放完不会循环
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("open"):
		animated_sprite.sprite_frames.set_animation_loop("open", false)
		
	# 初始播放上锁动画
	animated_sprite.play("lock")
	
	# 监听动画播放完成信号
	animated_sprite.animation_finished.connect(_on_animation_finished)

func open_door() -> void:
	# 发出开门信号
	door_opened.emit()
	
	# 播放开门动画
	animated_sprite.play("open")

func _on_animation_finished() -> void:
	if animated_sprite.animation == "open":
		# 当开门动画播放完毕后，禁用物理碰撞，让玩家可以通过，并销毁自身
		collision_shape.set_deferred("disabled", true)
		queue_free()

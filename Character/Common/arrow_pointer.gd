extends Node2D

class_name ArrowPointer

var target_angle: float = 0.0
var is_first_update: bool = true

var sprite: Sprite2D
const ArrowScene = preload("res://Scenes/UI/arrow_pointer.tscn")

func _ready() -> void:
	# 确保在暂停时也可以渲染
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100 # Ensure it draws on top of characters
	
	if ArrowScene != null:
		sprite = ArrowScene.instantiate() as Sprite2D
		# 因为场景里的箭头是垂直向上的 (指向 Vector2.UP 或 y = -1)，
		# 而我们在代码中默认 0 度是向右 (Vector2.RIGHT 或 x = 1)。
		# 我们把 Sprite2D 预先顺时针旋转 90 度（即 PI / 2），让它默认向右。
		# 或者通过把 target_angle + PI/2，这里我们在外层控制
		sprite.rotation = PI / 2.0
		# 把箭头向右偏移一段距离，调小数值让箭头离角色更近
		sprite.position = Vector2(20.0, 0.0) 
		# 如果需要缩放可以调整 scale
		sprite.scale = Vector2(0.5, 0.5) 
		add_child(sprite)

func _process(delta: float) -> void:
	# 平滑旋转箭头，由于时间可能被缩放，使用真实时间的delta进行插值
	var real_delta = delta / Engine.time_scale if Engine.time_scale > 0 else delta
	rotation = lerp_angle(rotation, target_angle, 4.0 * real_delta)

func update_direction(dir: Vector2) -> void:
	if dir.length_squared() > 0.01:
		target_angle = dir.angle()
		if is_first_update:
			rotation = target_angle
			is_first_update = false

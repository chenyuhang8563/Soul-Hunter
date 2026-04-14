extends Sprite2D
class_name Afterimage

# 当拖影完成生命周期时，发出信号，通知character脚本回收自己
var _release_cb: Callable = Callable()

# 接受所有必要的参数来初始化自己
func initialize(
	p_texture: Texture2D,
	p_hframes: int,
	p_vframes: int,
	p_frame: int,
	p_transform: Transform2D,
	p_flip_h: bool,
	p_offset: Vector2,
	p_centered: bool,
	p_color: Color,
	p_duration: float,
	p_final_scale: float,
	release_cb: Callable = Callable()
) -> void:
	_release_cb = release_cb
	# 1.立即启用所有视觉状态
	texture = p_texture
	hframes = max(1, p_hframes)
	vframes = max(1, p_vframes)
	self.frame = p_frame
	self.global_transform = p_transform
	self.flip_h = p_flip_h
	offset = p_offset
	centered = p_centered
	self.modulate = p_color
	scale = Vector2.ONE

	# 2.激活并显示自己
	visible = true

	# 3.创建并启动淡出和缩小动画
	var tween = create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 0.0, p_duration)
	tween.tween_property(self, "scale", self.scale * p_final_scale, p_duration)

	# 4.动画完成后，隐藏自己并发出回收信号
	tween.finished.connect(_on_fade_out_finished)

func reset_state() -> void:
	visible = false
	texture = null
	modulate = Color(1, 1, 1, 1)
	scale = Vector2.ONE
	_release_cb = Callable()

func _on_fade_out_finished() -> void:
	var release_cb := _release_cb
	reset_state()
	if release_cb.is_valid():
		release_cb.call()

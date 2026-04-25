# Scenes/Items/item.gd
## 通用物品场景脚本 —— 通过精灵表设置动画帧
class_name Item
extends AnimatedSprite2D

## 从精灵表纹理设置动画帧
## texture: 精灵表纹理（水平排列的帧）
## frame_size: 每帧大小（默认 8x8）
## speed: 播放速度（默认 5.0）
func setup(texture: Texture2D, frame_size := Vector2i(8, 8), speed := 5.0) -> void:
	if texture == null:
		return

	var tex_size := texture.get_size()
	if tex_size.x <= 0 or tex_size.y <= 0:
		return

	var columns := int(tex_size.x) / maxi(frame_size.x, 1)

	var new_frames := SpriteFrames.new()
	new_frames.add_animation("default")
	new_frames.set_animation_speed("default", speed)
	new_frames.set_animation_loop("default", true)

	for i in columns:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2i(i * frame_size.x, 0, frame_size.x, frame_size.y)
		new_frames.add_frame("default", atlas)

	sprite_frames = new_frames
	play("default")


## 从配置中设置物品外观
func setup_from_config(config) -> void:
	if config == null:
		return
	var tex := load(config.icon_path) if config.icon_path != "" else null
	if tex != null:
		setup(tex)

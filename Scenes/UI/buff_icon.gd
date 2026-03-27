extends Sprite2D

const FULL_CIRCLE := TAU
const START_ANGLE := -PI * 0.5
const SEGMENT_COUNT := 48
const MASK_COLOR := Color(0.533, 0.533, 0.533, 0.7)

@onready var cooldown_mask: Polygon2D = $CooldownMask

var tracked_buff = null
var clockwise := true

func _ready() -> void:
	if cooldown_mask != null:
		cooldown_mask.color = MASK_COLOR
	_update_cooldown_mask()

func _process(_delta: float) -> void:
	_update_cooldown_mask()

func bind_buff(buff) -> void:
	tracked_buff = buff
	_update_cooldown_mask()

func set_icon_texture(icon_texture: Texture2D) -> void:
	texture = icon_texture
	_update_cooldown_mask()

func _update_cooldown_mask() -> void:
	if cooldown_mask == null:
		return
	if tracked_buff == null:
		cooldown_mask.visible = false
		return
	if bool(tracked_buff.is_permanent) or float(tracked_buff.duration) <= 0.0:
		cooldown_mask.visible = false
		return
	var progress: float = clampf(float(tracked_buff.remaining_time) / float(tracked_buff.duration), 0.0, 1.0)
	if progress <= 0.0:
		cooldown_mask.visible = false
		return
	cooldown_mask.visible = true
	cooldown_mask.polygon = _build_sector_polygon(progress)

func _build_sector_polygon(progress: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	if progress >= 0.9999:
		return _build_full_square_polygon()
	var sweep: float = FULL_CIRCLE * progress
	var steps: int = maxi(1, int(ceil(SEGMENT_COUNT * progress)))
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var angle_offset: float = sweep * t
		var angle: float = START_ANGLE - angle_offset if clockwise else START_ANGLE + angle_offset
		points.append(_get_square_boundary_point(angle))
	return points

func _build_full_square_polygon() -> PackedVector2Array:
	var points := PackedVector2Array()
	var half_size: Vector2 = _get_half_size()
	points.append(Vector2(-half_size.x, -half_size.y))
	points.append(Vector2(half_size.x, -half_size.y))
	points.append(Vector2(half_size.x, half_size.y))
	points.append(Vector2(-half_size.x, half_size.y))
	return points

func _get_square_boundary_point(angle: float) -> Vector2:
	var direction: Vector2 = Vector2.RIGHT.rotated(angle)
	var half_size: Vector2 = _get_half_size()
	var scale_x := INF
	var scale_y := INF
	if not is_zero_approx(direction.x):
		scale_x = half_size.x / absf(direction.x)
	if not is_zero_approx(direction.y):
		scale_y = half_size.y / absf(direction.y)
	var ray_scale: float = minf(scale_x, scale_y)
	return direction * ray_scale

func _get_half_size() -> Vector2:
	if texture == null:
		return Vector2(8.0, 8.0)
	var size: Vector2 = texture.get_size()
	return size * 0.5

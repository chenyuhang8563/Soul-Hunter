extends Area2D
class_name WerebearShockWave

const DEFAULT_INITIAL_SCALE_X := 1.0
const DEFAULT_SCALE_Y := 1.0

static var _cast_hit_targets: Dictionary = {}

@onready var shockwave_sprite: AnimatedSprite2D = $ShockWaveSprite

var damage_delegate: Object = null
var hit_callback: Callable = Callable()
var damage_delegate_instance_id := 0
var cast_id := 0
var damage_amount := 0.0
var fullscreen_mode := false
var target_scale_x := DEFAULT_INITIAL_SCALE_X
var expand_duration := 0.0
var hold_duration := 0.0
var damage_window := 0.0
var initial_scale_x := DEFAULT_INITIAL_SCALE_X
var scale_y := DEFAULT_SCALE_Y

var _setup_complete := false
var _wave_started := false
var _active_tween: Tween = null
var _damage_tween: Tween = null
var _hit_target_ids: Dictionary = {}

func _ready() -> void:
	monitoring = false
	body_entered.connect(_on_body_entered)
	set_physics_process(false)
	if _setup_complete:
		_start_wave()

func setup(config: Dictionary) -> void:
	damage_delegate = config.get("damage_delegate")
	hit_callback = config.get("hit_callback", Callable())
	damage_delegate_instance_id = 0
	if damage_delegate != null and is_instance_valid(damage_delegate):
		damage_delegate_instance_id = damage_delegate.get_instance_id()
	cast_id = int(config.get("cast_id", 0))
	damage_amount = maxf(0.0, float(config.get("damage", 0.0)))
	fullscreen_mode = bool(config.get("fullscreen_mode", false))
	target_scale_x = maxf(DEFAULT_INITIAL_SCALE_X, float(config.get("target_scale_x", DEFAULT_INITIAL_SCALE_X)))
	expand_duration = maxf(0.0, float(config.get("expand_duration", 0.0)))
	hold_duration = maxf(0.0, float(config.get("hold_duration", 0.0)))
	damage_window = minf(hold_duration, maxf(0.0, float(config.get("damage_window", hold_duration))))
	initial_scale_x = maxf(0.05, float(config.get("initial_scale_x", DEFAULT_INITIAL_SCALE_X)))
	scale_y = maxf(0.05, float(config.get("scale_y", DEFAULT_SCALE_Y)))
	collision_layer = int(config.get("collision_layer", collision_layer))
	collision_mask = int(config.get("collision_mask", collision_mask))
	scale = Vector2(initial_scale_x, scale_y)
	_setup_complete = true
	_hit_target_ids.clear()
	_wave_started = false
	_stop_active_tween()
	_stop_damage_tween()

	if is_inside_tree():
		_start_wave()

func is_fullscreen_mode() -> bool:
	return fullscreen_mode

func _physics_process(_delta: float) -> void:
	_refresh_overlap_hits()

func _start_wave() -> void:
	if _wave_started:
		return
	_wave_started = true
	monitoring = true
	set_physics_process(true)
	if shockwave_sprite != null:
		shockwave_sprite.play(&"default")
	call_deferred("_refresh_overlap_hits")
	call_deferred("_refresh_group_overlap_hits")

	_damage_tween = create_tween()
	_damage_tween.tween_interval(damage_window)
	_damage_tween.finished.connect(_disable_damage)

	_active_tween = create_tween()
	_active_tween.tween_property(self, "scale:x", target_scale_x, expand_duration)
	_active_tween.tween_interval(hold_duration)
	_active_tween.finished.connect(_finish_wave)

func _disable_damage() -> void:
	monitoring = false
	set_physics_process(false)
	_stop_damage_tween()

func _finish_wave() -> void:
	_disable_damage()
	_stop_active_tween()
	queue_free()

func _stop_active_tween() -> void:
	if _active_tween != null and is_instance_valid(_active_tween):
		_active_tween.kill()
	_active_tween = null

func _stop_damage_tween() -> void:
	if _damage_tween != null and is_instance_valid(_damage_tween):
		_damage_tween.kill()
	_damage_tween = null

func _refresh_overlap_hits() -> void:
	if not monitoring:
		return
	for body in get_overlapping_bodies():
		if body == null or not is_instance_valid(body):
			continue
		if body is Node2D:
			_try_apply_hit(body as Node2D)
	_refresh_group_overlap_hits()

func _refresh_group_overlap_hits() -> void:
	if damage_delegate == null or not is_instance_valid(damage_delegate):
		return
	if not damage_delegate.has_method("_is_valid_damage_target"):
		return
	var owner_node = damage_delegate.get("owner")
	if owner_node == null or not is_instance_valid(owner_node):
		return
	if not (owner_node is Node2D):
		return
	var owner_2d := owner_node as Node2D
	if not owner_2d.is_inside_tree():
		return
	for candidate in owner_2d.get_tree().get_nodes_in_group("possessable_character"):
		if candidate == null or not is_instance_valid(candidate):
			continue
		if not (candidate is Node2D):
			continue
		var body := candidate as Node2D
		if not body.is_inside_tree():
			continue
		if not _contains_point(body.global_position):
			continue
		_try_apply_hit(body)

func _contains_point(world_point: Vector2) -> bool:
	for child in get_children():
		if not (child is CollisionShape2D):
			continue
		var shape_node := child as CollisionShape2D
		if shape_node.disabled or not (shape_node.shape is RectangleShape2D):
			continue
		var rect_shape := shape_node.shape as RectangleShape2D
		var extents := rect_shape.size * shape_node.global_scale * 0.5
		var delta := world_point - shape_node.global_position
		if absf(delta.x) <= extents.x and absf(delta.y) <= extents.y:
			return true
	return false

func _on_body_entered(body: Node2D) -> void:
	_try_apply_hit(body)

func _try_apply_hit(body: Node2D) -> void:
	if body == null or not is_instance_valid(body):
		return
	if damage_delegate == null or not is_instance_valid(damage_delegate):
		return
	if not body.is_inside_tree():
		return
	if not damage_delegate.has_method("_is_valid_damage_target"):
		return
	if not bool(damage_delegate.call("_is_valid_damage_target", body)):
		return

	var target_id := body.get_instance_id()
	if _hit_target_ids.has(target_id):
		return
	_hit_target_ids[target_id] = true
	if damage_delegate_instance_id != 0:
		var cast_key := "%s:%s" % [damage_delegate_instance_id, cast_id]
		var hit_targets: Dictionary = _cast_hit_targets.get(cast_key, {})
		if hit_targets.has(target_id):
			return
		hit_targets[target_id] = true
		_cast_hit_targets[cast_key] = hit_targets

	if not hit_callback.is_null():
		hit_callback.call(cast_id, body, damage_amount)
	elif damage_delegate.has_method("register_shockwave_hit"):
		damage_delegate.call("register_shockwave_hit", cast_id, body, damage_amount)
	elif damage_delegate.has_method("_apply_damage_to_target"):
		damage_delegate.call("_apply_damage_to_target", body, damage_amount, false, {})

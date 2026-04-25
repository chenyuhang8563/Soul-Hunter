class_name PickupItem
extends Node2D

@export var item_id: int = 0
@export var count: int = 1
@export var jump_height: float = 24.0
@export var jump_up_duration: float = 0.12
@export var jump_down_duration: float = 0.18

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _pickup_area: Area2D = $PickupArea

var _is_landed := false
var _is_collected := false
var _can_pick_up := false
var _player_body: CharacterBody2D
var _collector_getter: Callable


func _ready() -> void:
	_player_body = _resolve_collector_body()

	if is_instance_valid(_sprite):
		_sprite.play()

	if not is_instance_valid(_pickup_area):
		return

	_pickup_area.monitoring = true
	_pickup_area.monitorable = true

	if is_instance_valid(_player_body):
		_pickup_area.collision_mask |= _player_body.collision_layer

	if not _pickup_area.body_entered.is_connected(_on_pickup_area_body_entered):
		_pickup_area.body_entered.connect(_on_pickup_area_body_entered)
	if not _pickup_area.body_exited.is_connected(_on_pickup_area_body_exited):
		_pickup_area.body_exited.connect(_on_pickup_area_body_exited)
	if not _pickup_area.body_shape_entered.is_connected(_on_pickup_area_body_shape_entered):
		_pickup_area.body_shape_entered.connect(_on_pickup_area_body_shape_entered)
	if not _pickup_area.body_shape_exited.is_connected(_on_pickup_area_body_shape_exited):
		_pickup_area.body_shape_exited.connect(_on_pickup_area_body_shape_exited)

func setup(new_item_id: int, new_count: int = 1) -> void:
	item_id = new_item_id
	count = new_count


func set_collector_body(body: CharacterBody2D) -> void:
	_player_body = body
	_update_pickup_mask_from_player()


func set_collector_getter(getter: Callable) -> void:
	_collector_getter = getter
	_player_body = _resolve_collector_body()


func jump_out(start_pos: Vector2) -> void:
	global_position = start_pos
	scale = Vector2.ONE
	modulate = Color.WHITE
	_is_landed = false
	_is_collected = false
	_can_pick_up = false

	var apex := start_pos + Vector2(0.0, -jump_height)
	var tween := create_tween()
	tween.tween_property(self, "global_position", apex, jump_up_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", start_pos, jump_down_duration).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_jump_finished)


func collect() -> void:
	if _is_collected:
		return

	_is_collected = true

	if is_instance_valid(_pickup_area):
		_pickup_area.set_deferred("monitoring", false)
		_pickup_area.set_deferred("monitorable", false)

	if item_id != 0:
		PropManager.add_prop(item_id, count)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	tween.finished.connect(queue_free)


func _on_jump_finished() -> void:
	_is_landed = true
	_refresh_pickup_state()

	if _can_pick_up:
		collect()


func _on_pickup_area_body_entered(body: Node2D) -> void:
	if not _is_player_body(body):
		return

	_can_pick_up = true
	if _is_landed:
		collect()


func _on_pickup_area_body_exited(body: Node2D) -> void:
	if _is_collected:
		return

	if not _is_player_body(body):
		return

	_refresh_pickup_state()


func _on_pickup_area_body_shape_entered(_body_rid: RID, body: Node2D, _body_shape_index: int, _local_shape_index: int) -> void:
	if not _is_player_body(body):
		return

	_can_pick_up = true
	if _is_landed:
		collect()


func _on_pickup_area_body_shape_exited(_body_rid: RID, body: Node2D, _body_shape_index: int, _local_shape_index: int) -> void:
	if _is_collected:
		return

	if not _is_player_body(body):
		return

	_refresh_pickup_state()


func _refresh_pickup_state() -> void:
	_can_pick_up = false

	if _is_collected:
		return

	if not is_instance_valid(_pickup_area):
		return

	if not _pickup_area.monitoring:
		return

	for body in _pickup_area.get_overlapping_bodies():
		if _is_player_body(body):
			_can_pick_up = true
			return


func _is_player_body(body: Node) -> bool:
	if body == null:
		return false

	if not (body is CharacterBody2D):
		return false

	_player_body = _resolve_collector_body()
	return body == _player_body


func _resolve_collector_body() -> CharacterBody2D:
	if _collector_getter.is_valid():
		var resolved = _collector_getter.call()
		if resolved is CharacterBody2D:
			_player_body = resolved as CharacterBody2D

	if not is_instance_valid(_player_body):
		_player_body = _find_player_body()

	_update_pickup_mask_from_player()
	return _player_body


func _update_pickup_mask_from_player() -> void:
	if not is_instance_valid(_pickup_area):
		return

	if is_instance_valid(_player_body):
		_pickup_area.collision_mask |= _player_body.collision_layer


func _find_player_body() -> CharacterBody2D:
	var from_controller := _find_player_body_from_controller()
	if from_controller != null:
		return from_controller

	var by_group := get_tree().get_first_node_in_group("player")
	if by_group is CharacterBody2D:
		return by_group as CharacterBody2D

	var by_group_upper := get_tree().get_first_node_in_group("Player")
	if by_group_upper is CharacterBody2D:
		return by_group_upper as CharacterBody2D

	var by_name := get_tree().current_scene.find_child("Player", true, false)
	if by_name is CharacterBody2D:
		return by_name as CharacterBody2D

	return null


func _find_player_body_from_controller() -> CharacterBody2D:
	var scene := get_tree().current_scene
	if scene == null:
		return null

	var pending: Array[Node] = [scene]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		var candidate: CharacterBody2D = _extract_player_property(current)
		if candidate != null:
			return candidate

		for child in current.get_children():
			if child is Node:
				pending.append(child)

	return null


func _extract_player_property(node: Node) -> CharacterBody2D:
	for property: Dictionary in node.get_property_list():
		if String(property.name) != "_player":
			continue

		var candidate: Variant = node.get("_player")
		if candidate is CharacterBody2D:
			return candidate as CharacterBody2D

	return null

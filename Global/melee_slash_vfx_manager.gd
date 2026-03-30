extends Node

const CutScene := preload("res://Scenes/VFX/cut.tscn")
const POOL_PREWARM_COUNT := 8
const EFFECT_ROOT_NAME := "MeleeSlashVfxRoot"
const EFFECT_Z_INDEX := 10

var _container: Node2D = null
var _available: Array[Node] = []
var _active: Array[Node] = []

func _ready() -> void:
	_ensure_container()

func play_slash(source: Node2D, spec: Dictionary, attack_range: float) -> void:
	if source == null or not is_instance_valid(source):
		return
	_ensure_container()
	if _container == null:
		return
	var effect := _acquire_effect()
	if effect == null:
		return
	var resolved_spec := spec.duplicate(true)
	var reference_range := maxf(float(spec.get("reference_range", 1.0)), 0.001)
	resolved_spec["length_scale"] = clampf(attack_range / reference_range, 0.85, 1.6)
	if effect.get_parent() != _container:
		if effect.get_parent() != null:
			effect.reparent(_container)
		else:
			_container.add_child(effect)
	effect.z_as_relative = false
	effect.z_index = EFFECT_Z_INDEX
	_active.append(effect)
	var release_cb := Callable(self, "_release_effect").bind(effect)
	effect.call("play_once", _get_model_edge_anchor(source), _is_facing_left(source), resolved_spec, release_cb)

func _ensure_container() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var current_scene := tree.current_scene
	if current_scene == null:
		return
	var should_rebuild := _container == null or not is_instance_valid(_container) or _container.get_parent() != current_scene
	if should_rebuild:
		_available.clear()
		_active.clear()
		_container = Node2D.new()
		_container.name = EFFECT_ROOT_NAME
		current_scene.add_child(_container)
		_prewarm_pool(POOL_PREWARM_COUNT)
		return
	_prune_effect_lists()

func _acquire_effect() -> Node:
	_prune_effect_lists()
	if _available.is_empty():
		_prewarm_pool(1)
	if _available.is_empty():
		return null
	return _available.pop_back()

func _prewarm_pool(count: int) -> void:
	if _container == null:
		return
	for i in count:
		var effect := CutScene.instantiate()
		if effect == null:
			continue
		_container.add_child(effect)
		if effect.has_method("reset_state"):
			effect.call("reset_state")
		else:
			effect.visible = false
		_available.append(effect)

func _release_effect(effect: Node) -> void:
	if effect == null or not is_instance_valid(effect):
		return
	_active.erase(effect)
	if effect.has_method("reset_state"):
		effect.call("reset_state")
	if _container != null and is_instance_valid(_container) and effect.get_parent() != _container:
		if effect.get_parent() != null:
			effect.reparent(_container)
		else:
			_container.add_child(effect)
	if not _available.has(effect):
		_available.append(effect)

func _prune_effect_lists() -> void:
	var next_available: Array[Node] = []
	for effect in _available:
		if effect != null and is_instance_valid(effect):
			next_available.append(effect)
	_available = next_available
	var next_active: Array[Node] = []
	for effect in _active:
		if effect != null and is_instance_valid(effect):
			next_active.append(effect)
	_active = next_active

func _is_facing_left(source: Node2D) -> bool:
	var sprite := _find_sprite(source)
	return sprite != null and sprite.flip_h

func _get_model_edge_anchor(source: Node2D) -> Vector2:
	var sprite := _find_sprite(source)
	if sprite == null:
		return source.global_position
	var rect := sprite.get_rect()
	var anchor_local_x := rect.position.x + rect.size.x if sprite.flip_h else rect.position.x
	var anchor_local_y := rect.position.y + rect.size.y * 0.5
	return sprite.to_global(Vector2(anchor_local_x, anchor_local_y))

func _find_sprite(source: Node2D) -> Sprite2D:
	if source == null:
		return null
	if source.has_method("get"):
		var sprite_prop = source.get("sprite")
		if sprite_prop is Sprite2D:
			return sprite_prop as Sprite2D
	var named_sprite := source.get_node_or_null("Sprite2D") as Sprite2D
	if named_sprite != null:
		return named_sprite
	named_sprite = source.get_node_or_null("Soldier") as Sprite2D
	if named_sprite != null:
		return named_sprite
	for child in source.get_children():
		if child is Sprite2D:
			return child as Sprite2D
	return null

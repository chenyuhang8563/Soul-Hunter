extends Node

const ROOT_NAME := "WorldVfxRoot"
const CUT_Z_INDEX := 10

const CutScene := preload("res://Scenes/VFX/cut.tscn")
const AfterimageScene := preload("res://Scenes/VFX/afterimage.tscn")
const ExplosionScene := preload("res://Scenes/VFX/explosion.tscn")

var _scene_root: Node2D = null
var _registry: Dictionary = {}
var _available: Dictionary = {}
var _active: Dictionary = {}


func _ready() -> void:
	_registry = _build_default_registry()
	_available = {}
	_active = {}
	for key in _registry.keys():
		_available[key] = []
		_active[key] = []


func _build_default_registry() -> Dictionary:
	return {
		"cut": {"scene": CutScene, "prewarm": 8},
		"afterimage": {"scene": AfterimageScene, "prewarm": 15},
		"explosion": {"scene": ExplosionScene, "prewarm": 6},
		"hurt_particles": {"scene": null, "prewarm": 4},
		"parry_particles": {"scene": null, "prewarm": 4},
		"finisher_burst": {"scene": null, "prewarm": 2},
		"finisher_slash": {"scene": null, "prewarm": 2},
	}


func _ensure_scene_root() -> Node2D:
	var tree := get_tree()
	if tree == null:
		return null
	var current_scene := tree.current_scene
	if current_scene == null:
		return null

	var can_reuse_root := _scene_root != null and is_instance_valid(_scene_root) and _scene_root.get_parent() == current_scene
	if can_reuse_root:
		return _scene_root

	var existing_root := current_scene.get_node_or_null(ROOT_NAME) as Node2D
	if existing_root != null:
		_scene_root = existing_root
		return _scene_root

	_scene_root = Node2D.new()
	_scene_root.name = ROOT_NAME
	current_scene.add_child(_scene_root)
	return _scene_root


func play_cut(source: Node2D, spec: Dictionary, _attack_range: float) -> void:
	if source == null or not is_instance_valid(source):
		return
	var effect := _acquire_scene_effect(&"cut")
	if effect == null:
		return
	effect.z_as_relative = false
	effect.z_index = CUT_Z_INDEX
	var active_for_key: Array = _active[&"cut"]
	active_for_key.append(effect)
	var release_cb := Callable(self, "_release_effect").bind(&"cut", effect)
	effect.call("play_once", _get_model_edge_anchor(source), _is_facing_left(source), spec.duplicate(true), release_cb)


func _acquire_scene_effect(effect_key: StringName) -> Node:
	var root := _ensure_scene_root()
	if root == null:
		return null
	if not _registry.has(effect_key):
		return null
	if not _available.has(effect_key):
		_available[effect_key] = []
	if not _active.has(effect_key):
		_active[effect_key] = []
	_prune_effect_list(effect_key, _available)
	_prune_effect_list(effect_key, _active)
	var available_for_key: Array = _available[effect_key]
	if available_for_key.is_empty():
		var entry: Dictionary = _registry[effect_key]
		var prewarm_count := int(entry.get("prewarm", 1))
		_prewarm_scene_effect(effect_key, maxi(prewarm_count, 1))
	if available_for_key.is_empty():
		return null
	var effect := available_for_key.pop_back() as Node
	if effect == null or not is_instance_valid(effect):
		return null
	if effect.get_parent() != root:
		if effect.get_parent() != null:
			effect.reparent(root)
		else:
			root.add_child(effect)
	return effect


func _prewarm_scene_effect(effect_key: StringName, count: int) -> void:
	if count <= 0 or not _registry.has(effect_key):
		return
	var root := _ensure_scene_root()
	if root == null:
		return
	var entry: Dictionary = _registry[effect_key]
	var packed_scene = entry.get("scene")
	if not (packed_scene is PackedScene):
		return
	if not _available.has(effect_key):
		_available[effect_key] = []
	var available_for_key: Array = _available[effect_key]
	for i in count:
		var effect := (packed_scene as PackedScene).instantiate()
		if effect == null:
			continue
		root.add_child(effect)
		if effect.has_method("reset_state"):
			effect.call("reset_state")
		else:
			effect.visible = false
		available_for_key.append(effect)


func _release_effect(effect_key: StringName, effect: Node) -> void:
	if effect == null or not is_instance_valid(effect):
		return
	if not _active.has(effect_key):
		_active[effect_key] = []
	if not _available.has(effect_key):
		_available[effect_key] = []
	var active_for_key: Array = _active[effect_key]
	active_for_key.erase(effect)
	if effect.has_method("reset_state"):
		effect.call("reset_state")
	else:
		effect.visible = false
	var root := _ensure_scene_root()
	if root != null and effect.get_parent() != root:
		if effect.get_parent() != null:
			effect.reparent(root)
		else:
			root.add_child(effect)
	var available_for_key: Array = _available[effect_key]
	if not available_for_key.has(effect):
		available_for_key.append(effect)


func _prune_effect_list(effect_key: StringName, bucket: Dictionary) -> void:
	if not bucket.has(effect_key):
		bucket[effect_key] = []
	var next_items: Array = []
	for effect in bucket[effect_key]:
		if effect != null and is_instance_valid(effect):
			next_items.append(effect)
	bucket[effect_key] = next_items


func _is_facing_left(source: Node2D) -> bool:
	var sprite := _find_sprite(source)
	return sprite != null and sprite.flip_h


func _get_model_edge_anchor(source: Node2D) -> Vector2:
	var sprite := _find_sprite(source)
	if sprite == null:
		return source.global_position
	var rect := sprite.get_rect()
	var anchor_local_x := rect.position.x + rect.size.x * 0.5
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

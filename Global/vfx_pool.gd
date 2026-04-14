extends Node

const ROOT_NAME := "WorldVfxRoot"

const CutScene := preload("res://Scenes/VFX/cut.tscn")
const AfterimageScene := preload("res://Scenes/VFX/afterimage.tscn")
const ExplosionScene := preload("res://Scenes/VFX/explosion.tscn")

var _scene_root: Node2D = null
var _registry: Dictionary = {}
var _available: Dictionary = {}
var _active: Dictionary = {}


func _ready() -> void:
	_registry = _build_default_registry()


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

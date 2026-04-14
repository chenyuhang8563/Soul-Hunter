extends Node


func play_slash(source: Node2D, spec: Dictionary, attack_range: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var pool := tree.root.get_node_or_null("VfxPool")
	if pool == null or not pool.has_method("play_cut"):
		return
	pool.call("play_cut", source, spec, attack_range)

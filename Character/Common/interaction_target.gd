class_name InteractionTarget
extends RefCounted

static func is_valid_target(node: Node) -> bool:
	return node != null and node.has_method("can_interact") and node.has_method("interact")

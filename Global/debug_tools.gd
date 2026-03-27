class_name DebugTools
extends RefCounted

static func log(context: Node, message: String) -> void:
	if context == null or message.is_empty():
		return
	if not (context is CharacterBody2D):
		return
	if not DeveloperMode.applies_to(context as CharacterBody2D):
		return
	print("[%s] %s" % [context.name, message])

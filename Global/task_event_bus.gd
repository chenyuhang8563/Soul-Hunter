extends Node

signal fact_published(fact_id: StringName, value: Variant)

func publish_fact(fact_id: StringName, value: Variant = true) -> void:
	if fact_id == &"":
		return

	fact_published.emit(fact_id, value)

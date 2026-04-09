extends Node2D
class_name DamageNumberSpawner

@export var label_settings : LabelSettings
@export var critical_hit_color : Color = Color.YELLOW

func spawn_label(number: float, critical_hit: bool = false) -> void:
	var new_label : Label = Label.new()

	new_label.text = str(number if step_decimals(number) != 0 else number as int)
	new_label.label_settings = label_settings.duplicate()
	new_label.z_index = 1000
	new_label.pivot_offset_ratio = Vector2(0.5, 1.0)

	if critical_hit:
		new_label.label_settings.font_color = critical_hit_color

	# ignore 2d light node's effect (optional)
	var label_material: CanvasItemMaterial = CanvasItemMaterial.new()
	label_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	new_label.material = label_material

	call_deferred("add_child", new_label)
	await new_label.resized
	new_label.position = Vector2(new_label.size.x / 2.0, new_label.size.y)

	# animation of label
	var target_rise_pos : Vector2 = new_label.position + Vector2(randf_range(-3.0, 3.0),randf_range(-22.0, -16.0))
	var tween_length : float = 1.52
	var label_tween : Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	label_tween.tween_property(new_label, "position", target_rise_pos, tween_length)
	label_tween.parallel().tween_property(new_label, "scale", Vector2.ONE * 1.35, tween_length)
	label_tween.parallel().tween_property(new_label, "modulate:a", 0.0, tween_length).connect("finished", new_label.queue_free)

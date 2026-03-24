extends CanvasLayer

signal dialogue_finished
signal option_selected(next_id)

@onready var control = $Control
@onready var panel_container = $Control/PanelContainer
@onready var avatar = $Control/PanelContainer/HBoxContainer/Avatar
@onready var avatar_sprite = $Control/PanelContainer/HBoxContainer/Avatar/AvatarSprite
@onready var name_label = $Control/PanelContainer/HBoxContainer/VBoxContainer/NameLabel
@onready var text_label = $Control/PanelContainer/HBoxContainer/VBoxContainer/TextLabel
@onready var next_indicator = $Control/NextIndicator
@onready var options_container = $Control/OptionsContainer

var current_text: String = ""
var text_speed: float = 0.05
var is_typing: bool = false
var text_tween: Tween
var indicator_tween: Tween
var current_options: Array = []
var wait_for_input: bool = false

func _ready():
	hide_dialogue()
	setup_indicator_animation()

func setup_indicator_animation():
	# Setup simple up/down animation for the indicator
	next_indicator.hide()

func show_dialogue(dialogue_node: Dictionary):
	control.show()
	self.show()
	
	# Clear old options
	for child in options_container.get_children():
		child.queue_free()
	options_container.hide()
	
	# Set data
	if dialogue_node.has("name"):
		name_label.text = dialogue_node["name"]
	else:
		name_label.text = ""
		
	if dialogue_node.has("avatar") and dialogue_node["avatar"] != null:
		avatar_sprite.texture = dialogue_node["avatar"]
		avatar.show()
	else:
		avatar.hide()
		
	current_text = dialogue_node.get("text", "")
	text_label.text = current_text
	text_label.visible_ratio = 0.0
	
	current_options = dialogue_node.get("options", [])
	
	start_typing()

func start_typing():
	is_typing = true
	next_indicator.hide()
	wait_for_input = false
	
	if text_tween:
		text_tween.kill()
	text_tween = create_tween()
	
	# Calculate duration based on text length and speed
	# We strip bbcode for length calculation roughly
	var text_length = current_text.length()
	var duration = text_length * text_speed
	
	text_tween.tween_property(text_label, "visible_ratio", 1.0, duration)
	text_tween.finished.connect(_on_typing_finished)

func _on_typing_finished():
	is_typing = false
	text_label.visible_ratio = 1.0
	
	if current_options.size() > 0:
		show_options()
	else:
		wait_for_input = true
		show_indicator()

func show_options():
	options_container.show()
	var idx = 1
	for opt in current_options:
		var btn = Button.new()
		btn.text = str(idx) + ". " + opt.get("text", "")
		btn.add_theme_font_size_override("font_size", 6)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var next_id = opt.get("next_id", "")
		btn.pressed.connect(func(): _on_option_pressed(next_id))
		options_container.add_child(btn)
		idx += 1

func _on_option_pressed(next_id: String):
	option_selected.emit(next_id)

func show_indicator():
	next_indicator.show()
	if indicator_tween:
		indicator_tween.kill()
		
	indicator_tween = create_tween().set_loops()
	
	# Since it's no longer in the container, we can safely animate its global/local Y offset
	var base_y = next_indicator.position.y
	indicator_tween.tween_property(next_indicator, "position:y", base_y + 3, 0.5).set_trans(Tween.TRANS_SINE)
	indicator_tween.tween_property(next_indicator, "position:y", base_y, 0.5).set_trans(Tween.TRANS_SINE)

func hide_dialogue():
	self.hide()
	control.hide()
	is_typing = false
	wait_for_input = false

func _input(event):
	if not self.visible:
		return
		
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		if is_typing:
			# Skip typing
			if text_tween:
				text_tween.kill()
			_on_typing_finished()
			get_viewport().set_input_as_handled()
		elif wait_for_input:
			# Proceed to next or finish
			wait_for_input = false
			dialogue_finished.emit()
			get_viewport().set_input_as_handled()
			
	# Handle number keys for options
	if not is_typing and current_options.size() > 0:
		for i in range(current_options.size()):
			var key = KEY_1 + i
			if event is InputEventKey and event.pressed and event.keycode == key:
				var next_id = current_options[i].get("next_id", "")
				_on_option_pressed(next_id)
				get_viewport().set_input_as_handled()
				break

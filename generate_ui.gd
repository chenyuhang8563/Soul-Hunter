extends SceneTree

func _init():
    var canvas = CanvasLayer.new()
    canvas.name = "DialogueUI"
    canvas.layer = 100
    
    var control = Control.new()
    control.name = "Control"
    control.set_anchors_preset(Control.PRESET_FULL_RECT)
    canvas.add_child(control)
    control.owner = canvas
    
    var panel = PanelContainer.new()
    panel.name = "PanelContainer"
    panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    panel.offset_left = 10
    panel.offset_top = -60
    panel.offset_right = -10
    panel.offset_bottom = -10
    control.add_child(panel)
    panel.owner = canvas
    
    var hbox = HBoxContainer.new()
    hbox.name = "HBoxContainer"
    panel.add_child(hbox)
    hbox.owner = canvas
    
    var avatar = TextureRect.new()
    avatar.name = "Avatar"
    avatar.custom_minimum_size = Vector2(32, 32)
    avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    hbox.add_child(avatar)
    avatar.owner = canvas
    
    var vbox = VBoxContainer.new()
    vbox.name = "VBoxContainer"
    vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hbox.add_child(vbox)
    vbox.owner = canvas
    
    var name_label = Label.new()
    name_label.name = "NameLabel"
    name_label.text = "Name"
    name_label.add_theme_font_size_override("font_size", 10)
    name_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
    vbox.add_child(name_label)
    name_label.owner = canvas
    
    var text_label = RichTextLabel.new()
    text_label.name = "TextLabel"
    text_label.text = "Text"
    text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    text_label.bbcode_enabled = true
    text_label.add_theme_font_size_override("normal_font_size", 10)
    text_label.scroll_active = false
    vbox.add_child(text_label)
    text_label.owner = canvas
    
    var next_indicator = Label.new()
    next_indicator.name = "NextIndicator"
    next_indicator.text = "v"
    next_indicator.add_theme_font_size_override("font_size", 10)
    next_indicator.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    next_indicator.offset_left = -15
    next_indicator.offset_top = -20
    next_indicator.offset_right = -5
    next_indicator.offset_bottom = -5
    panel.add_child(next_indicator)
    next_indicator.owner = canvas
    
    var options_container = VBoxContainer.new()
    options_container.name = "OptionsContainer"
    options_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    options_container.offset_left = -110
    options_container.offset_top = 10
    options_container.offset_right = -10
    options_container.offset_bottom = 60
    options_container.alignment = BoxContainer.ALIGNMENT_END
    control.add_child(options_container)
    options_container.owner = canvas
    
    var packed_scene = PackedScene.new()
    packed_scene.pack(canvas)
    
    var dir = DirAccess.open("res://")
    if not dir.dir_exists("Scenes/UI"):
        dir.make_dir_recursive("Scenes/UI")
        
    ResourceSaver.save(packed_scene, "res://Scenes/UI/dialogue_ui.tscn")
    print("Saved DialogueUI scene!")
    quit()

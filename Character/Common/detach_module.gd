extends RefCounted
class_name DetachModule

const ArrowPointerScript = preload("res://Character/Common/arrow_pointer.gd")
var soldier_scene_path: String = "res://Character/Soldier/soldier.tscn"

var owner: CharacterBody2D
var is_aiming: bool = false
var aim_timer: float = 0.0
var max_aim_time: float = 5.0
var arrow_instance: Node2D
var current_direction: Vector2 = Vector2.RIGHT

func setup(_owner: CharacterBody2D) -> void:
	owner = _owner

func update(delta: float) -> void:
	if owner == null or not owner.is_inside_tree() or owner.is_dead:
		_cancel_aim()
		return

	if InputMap.has_action("detach") and Input.is_action_just_pressed("detach"):
		_start_aim()
	
	if is_aiming:
		# Use real time delta because Engine.time_scale is modified
		var real_delta = delta / Engine.time_scale if Engine.time_scale > 0 else delta
		aim_timer += real_delta
		
		_update_direction()
		
		if aim_timer >= max_aim_time or Input.is_action_just_released("detach"):
			_execute_detach()

func _start_aim() -> void:
	if is_aiming:
		return
	is_aiming = true
	aim_timer = 0.0
	Engine.time_scale = 0.1
	
	# Initial direction based on input or facing
	_update_direction()
	if current_direction.length_squared() < 0.01:
		var sprite = owner.call("_find_self_sprite") if owner.has_method("_find_self_sprite") else null
		if sprite != null and sprite.flip_h:
			current_direction = Vector2.LEFT
		else:
			current_direction = Vector2.RIGHT
	
	if arrow_instance == null:
		arrow_instance = ArrowPointerScript.new()
		owner.add_child(arrow_instance)
	arrow_instance.visible = true
	arrow_instance.update_direction(current_direction)

func _update_direction() -> void:
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir.length_squared() > 0.01:
		current_direction = input_dir.normalized()
		if arrow_instance != null:
			arrow_instance.update_direction(current_direction)

func _cancel_aim() -> void:
	if not is_aiming:
		return
	is_aiming = false
	Engine.time_scale = 1.0
	if arrow_instance != null:
		arrow_instance.visible = false
		arrow_instance.queue_free()
		arrow_instance = null

func _execute_detach() -> void:
	_cancel_aim()
	
	if not owner.is_inside_tree():
		return
		
	var parent = owner.get_parent()
	var spawn_pos = owner.global_position
	
	# 先杀死当前宿主（交出控制权和摄像机等状态）
	if owner.has_method("consume_for_possession"):
		owner.call("consume_for_possession")
	elif owner.has_method("apply_damage"):
		owner.call("apply_damage", 9999.0, null)
	
	# Spawn new Soldier
	if parent != null:
		var SoldierScene = load(soldier_scene_path)
		if SoldierScene != null:
			var soldier = SoldierScene.instantiate() as CharacterBody2D
			soldier.global_position = spawn_pos
			
			# 确保在进入场景树（触发 _ready）前，就标记为玩家控制，避免被错误分配到敌人阵营 (team_id = 1)
			if "start_player_controlled" in soldier:
				soldier.set("start_player_controlled", true)
				
			parent.add_child(soldier)
			
			# Set as player controlled and ensure correct team
			if soldier.has_method("set_player_controlled"):
				soldier.call("set_player_controlled", true)
			soldier.set("team_id", 0)
			
			# Apply Dash velocity
			soldier.velocity = current_direction * 300.0
			if "dash_velocity" in soldier:
				soldier.set("dash_velocity", current_direction * 300.0)
				soldier.set("dash_time_left", 0.3)
				
			var sprite = soldier.call("_find_self_sprite") if soldier.has_method("_find_self_sprite") else null
			if sprite != null and current_direction.x != 0:
				sprite.flip_h = current_direction.x < 0

func is_blocking_movement() -> bool:
	return is_aiming

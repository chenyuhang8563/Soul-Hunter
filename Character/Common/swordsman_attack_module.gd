extends "res://Character/Common/attack_module_base.gd"
class_name SwordsmanAttackModule

const LIGHT_ATTACK_DURATION := 0.70
const HARD_SEGMENT_COUNT := 3
# 重攻击3段时间定义（与动画关键帧对齐）：
# 第1段: 0.0s-0.5s (frames 45-50)
# 第2段: 0.5s-0.9s (frames 50-54)
# 第3段: 0.9s-1.5s (frames 54-59)
const HARD_ATTACK_TIMES := [0.0, 0.5, 0.9, 1.5]
const ULTIMATE_ATTACK_DURATION := 1.20
const ULTIMATE_ATTACK_RANGE := 64.0
const ULTIMATE_HIT_COUNT := 5
const ATTACK_COOLDOWN := 0.30
const LIGHT_ATTACK_HIT_DELAY := 0.40
const HARD_ATTACK_HIT_DELAYS := [0.45, 0.30, 0.45]
const HARD_COMBO_CHAIN_WINDOW := 0.45
const MELEE_ATTACK_RANGE := 44.0

var animation_player: AnimationPlayer

var hard_combo_step := 0
var hard_combo_chain_left := 0.0
var hard_waiting_next := false
var hard_attack_times := PackedFloat32Array(HARD_ATTACK_TIMES)
var ultimate_hit_times := PackedFloat32Array([0.08, 0.26, 0.44, 0.62, 0.80])

func setup(
		host: CharacterBody2D,
		sprite_node: Sprite2D = null,
		tree: AnimationTree = null,
		player: AnimationPlayer = null,
		_hitbox: Area2D = null,
		_hitbox_shape: CollisionShape2D = null,
		character_stats: CharacterStats = null,
		cooldown: float = ATTACK_COOLDOWN,
		audio_service_node: Node = null
) -> void:
	super.setup(host, sprite_node, tree, player, _hitbox, _hitbox_shape, character_stats, cooldown, audio_service_node)
	animation_player = player

func update(delta: float, target: Node2D = null, in_scope: bool = false) -> void:
	super.update(delta, target, in_scope)
	if current_attack == "" and hard_combo_chain_left > 0.0:
		hard_combo_chain_left = maxf(0.0, hard_combo_chain_left - delta)
		if hard_combo_chain_left == 0.0:
			_end_hard_combo_wait()

func try_start_from_input() -> void:
	# Check both InputBuffer (150ms window) and immediate input
	var buffered_hard := InputBuffer.is_action_press_buffered("hard_attack") or Input.is_action_just_pressed("hard_attack")
	var buffered_light := InputBuffer.is_action_press_buffered("light_attack") or Input.is_action_just_pressed("light_attack")
	var buffered_ultimate := InputBuffer.is_action_press_buffered("ultimate_attack") or Input.is_action_just_pressed("ultimate_attack")
	
	if buffered_ultimate:
		if can_start_attack():
			_end_hard_combo_wait()
			_start_ultimate_attack()
		return
	
	if buffered_hard:
		# Continue combo if in window
		if hard_combo_step > 0 and (hard_waiting_next or hard_combo_chain_left > 0.0):
			if hard_combo_step < HARD_SEGMENT_COUNT:
				attack_cooldown_left = 0.0
				hard_combo_step += 1
				hard_waiting_next = false
				hard_combo_chain_left = 0.0
				_start_hard_segment(hard_combo_step)
		elif can_start_attack():
			# Start new hard attack combo
			hard_combo_step = 1
			hard_waiting_next = false
			hard_combo_chain_left = 0.0
			_start_hard_segment(hard_combo_step)
		return
	
	if buffered_light:
		if can_start_attack():
			_end_hard_combo_wait()
			_start_light_attack()

func start_ai_attack() -> bool:
	if not can_start_attack():
		return false
	
	var rand := randf()
	if rand < 0.5: # 50% probability for light attack
		_end_hard_combo_wait()
		_start_light_attack()
	elif rand < 0.8: # 30% probability for hard attack
		_end_hard_combo_wait()
		hard_combo_step = 1
		hard_combo_chain_left = 0.0
		hard_waiting_next = false
		_start_hard_segment(hard_combo_step)
	else: # 20% probability for ultimate attack
		_end_hard_combo_wait()
		_start_ultimate_attack()
	
	return true

func _start_light_attack() -> void:
	animation_tree.active = true
	_begin_attack("light_attack", _get_light_attack_duration(LIGHT_ATTACK_DURATION), true, true, false, false)
	_queue_stat_damage_event(LIGHT_ATTACK_HIT_DELAY, &"light_attack_damage", stats.light_attack_damage, MELEE_ATTACK_RANGE, true, true)

func _start_ultimate_attack() -> void:
	animation_tree.active = true
	_begin_attack("ultimate_attack", ULTIMATE_ATTACK_DURATION, false, false, false, true)
	var hit_damage := _get_stat_value(&"ultimate_attack", stats.ultimate_attack) / float(ULTIMATE_HIT_COUNT)
	for hit_time in ultimate_hit_times:
		_queue_damage_event(float(hit_time), hit_damage, ULTIMATE_ATTACK_RANGE, false, false)

func _start_hard_segment(combo_step: int) -> void:
	# 计算当前段的持续时间
	var segment_start: float = HARD_ATTACK_TIMES[combo_step - 1]
	var segment_end: float = HARD_ATTACK_TIMES[combo_step]
	var segment_duration := segment_end - segment_start
	var segment_hit_delay: float = HARD_ATTACK_HIT_DELAYS[combo_step - 1]
	
	_begin_attack("hard_attack", segment_duration, false, false, true, false)
	_queue_stat_damage_event(segment_hit_delay, &"hard_attack_damage", stats.hard_attack_damage, MELEE_ATTACK_RANGE, true, true)
	if animation_player != null and animation_player.has_animation("hard_attack"):
		animation_tree.active = false
		# 恢复播放速度并定位到段开始
		animation_player.speed_scale = 1.0
		animation_player.play("hard_attack")
		animation_player.seek(segment_start, true)
	else:
		animation_tree.active = true

func _on_attack_finished(ended_attack: String) -> void:
	if ended_attack == "hard_attack":
		if owner != null and not bool(owner.get("is_player_controlled")):
			if hard_combo_step < HARD_SEGMENT_COUNT:
				attack_cooldown_left = 0.0
				hard_combo_step += 1
				_start_hard_segment(hard_combo_step)
			else:
				_end_hard_combo_wait()
			return
		
		# Player logic
		if hard_combo_step < HARD_SEGMENT_COUNT:
			# Enter combo waiting状态
			hard_waiting_next = true
			hard_combo_chain_left = HARD_COMBO_CHAIN_WINDOW
			if animation_player != null and animation_player.has_animation("hard_attack"):
				# 停在当前段的结束位置等待输入（使用 speed_scale=0 立即冻结）
				var segment_end_time: float = HARD_ATTACK_TIMES[hard_combo_step]
				animation_player.seek(segment_end_time, true)
				animation_player.speed_scale = 0.0
		else:
			_end_hard_combo_wait()

func _end_hard_combo_wait() -> void:
	var should_stop_player := hard_waiting_next or current_attack == "hard_attack" or hard_combo_step > 0
	hard_combo_step = 0
	hard_combo_chain_left = 0.0
	hard_waiting_next = false
	if animation_player != null:
		animation_player.speed_scale = 1.0
		if should_stop_player:
			animation_player.stop()
	animation_tree.active = true

func _on_force_stop() -> void:
	_end_hard_combo_wait()

extends Node2D

## 附身动画 VFX：灵魂从施法者飞向目标，附带爆发特效。
## 调用 play_once(source_pos, target_pos, _facing_left, release_cb) 触发。

const EMERGE_DURATION := 0.3
const TRAVEL_DURATION := 0.25
const BURST_DURATION := 0.45
const TOTAL_DURATION := EMERGE_DURATION + TRAVEL_DURATION + BURST_DURATION

const WISP_HFRAMES := 8
const WISP_VFRAMES := 8
const WISP_TOTAL_FRAMES := 61
const WISP_FPS := 18.0

const BURST_HFRAMES := 8
const BURST_VFRAMES := 8
const BURST_TOTAL_FRAMES := 61
const BURST_FPS := 22.0

const POSSESSION_PURPLE := Color(0.75, 0.3, 1.0)
const POSSESSION_GLOW := Color(0.9, 0.5, 1.0, 0.8)
const EFFECT_SCALE := 2.0

@onready var source_wisp: Sprite2D = $SourceWisp
@onready var target_wisp: Sprite2D = $TargetWisp
@onready var travel_orb: Sprite2D = $TravelOrb
@onready var trail_particles: GPUParticles2D = $TravelOrb/TrailParticles
@onready var burst_flash: Sprite2D = $BurstFlash

var _trail_process_material: ParticleProcessMaterial
var _release_cb: Callable = Callable()
var _play_serial := 0
var _source_pos: Vector2
var _target_pos: Vector2
var _active := false
var _elapsed := 0.0
var _wisp_frame := 0.0
var _burst_frame := 0.0


func _ready() -> void:
	var process_material := trail_particles.process_material as ParticleProcessMaterial
	if process_material != null:
		_trail_process_material = process_material.duplicate() as ParticleProcessMaterial
		trail_particles.process_material = _trail_process_material
	reset_state()


func play_once(source_pos: Vector2, target_pos: Vector2, _facing_left: bool, release_cb: Callable) -> void:
	_source_pos = source_pos
	_target_pos = target_pos
	_release_cb = release_cb
	_play_serial += 1
	_active = true
	_elapsed = 0.0
	_wisp_frame = 0.0
	_burst_frame = 0.0

	visible = true
	z_as_relative = false
	z_index = 10

	source_wisp.global_position = source_pos
	source_wisp.modulate = Color(POSSESSION_PURPLE.r, POSSESSION_PURPLE.g, POSSESSION_PURPLE.b, 0.0)
	source_wisp.frame = 0
	source_wisp.scale = Vector2.ONE * EFFECT_SCALE
	source_wisp.visible = true

	target_wisp.global_position = target_pos
	target_wisp.modulate = Color(POSSESSION_PURPLE.r, POSSESSION_PURPLE.g, POSSESSION_PURPLE.b, 0.0)
	target_wisp.frame = 0
	target_wisp.scale = Vector2.ONE * EFFECT_SCALE
	target_wisp.visible = true

	travel_orb.global_position = source_pos
	travel_orb.visible = false
	travel_orb.modulate = POSSESSION_GLOW

	burst_flash.global_position = target_pos
	burst_flash.modulate = Color(1, 1, 1, 0.0)
	burst_flash.visible = true
	burst_flash.scale = Vector2(0.3, 0.3) * EFFECT_SCALE

	trail_particles.restart()
	trail_particles.emitting = false
	set_process(true)


func reset_state() -> void:
	_play_serial += 1
	_active = false
	visible = false
	_release_cb = Callable()
	set_process(false)
	if source_wisp:
		source_wisp.modulate = Color(1, 1, 1, 0)
		source_wisp.frame = 0
		source_wisp.scale = Vector2.ONE * EFFECT_SCALE
	if target_wisp:
		target_wisp.modulate = Color(1, 1, 1, 0)
		target_wisp.frame = 0
		target_wisp.scale = Vector2.ONE * EFFECT_SCALE
	if travel_orb:
		travel_orb.visible = false
		travel_orb.scale = Vector2.ONE * EFFECT_SCALE
	if trail_particles:
		trail_particles.emitting = false
	if burst_flash:
		burst_flash.modulate = Color(1, 1, 1, 0)
		burst_flash.scale = Vector2.ONE * EFFECT_SCALE


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta

	# Phase 1: 灵魂在施法者身上显现然后收缩消失
	if _elapsed < EMERGE_DURATION:
		var t := _elapsed / EMERGE_DURATION
		_wisp_frame += delta * WISP_FPS
		source_wisp.frame = int(_wisp_frame) % WISP_TOTAL_FRAMES
		if t < 0.5:
			var fade_in := t / 0.5
			source_wisp.modulate.a = fade_in
			source_wisp.scale = Vector2(0.6 + 0.4 * fade_in, 0.6 + 0.4 * fade_in) * EFFECT_SCALE
		else:
			var fade_out := (t - 0.5) / 0.5
			source_wisp.modulate.a = 1.0 - fade_out
			source_wisp.scale = Vector2(1.0 - 0.7 * fade_out, 1.0 - 0.7 * fade_out) * EFFECT_SCALE

	# Phase 2: 灵魂光球从施法者飞向目标
	elif _elapsed < EMERGE_DURATION + TRAVEL_DURATION:
		source_wisp.visible = false
		travel_orb.visible = true
		trail_particles.emitting = true
		var travel_t := (_elapsed - EMERGE_DURATION) / TRAVEL_DURATION
		# 使用贝塞尔曲线（向上拱起）
		var mid_point := (_source_pos + _target_pos) * 0.5 + Vector2(0.0, -18.0)
		var pos := _quadratic_bezier(_source_pos, mid_point, _target_pos, travel_t)
		travel_orb.global_position = pos
		_set_trail_direction(_quadratic_bezier_tangent(_source_pos, mid_point, _target_pos, travel_t))
		# 光球脉动
		var pulse := 1.0 + 0.2 * sin(travel_t * TAU * 3.0)
		travel_orb.scale = Vector2(pulse, pulse) * EFFECT_SCALE

	# Phase 3: 到达目标，爆发特效
	elif _elapsed < TOTAL_DURATION:
		travel_orb.visible = false
		trail_particles.emitting = false
		var burst_t := (_elapsed - EMERGE_DURATION - TRAVEL_DURATION) / BURST_DURATION
		_burst_frame += delta * BURST_FPS
		target_wisp.frame = int(_burst_frame) % BURST_TOTAL_FRAMES

		if burst_t < 0.3:
			var appear := burst_t / 0.3
			target_wisp.modulate.a = appear
			target_wisp.scale = Vector2(0.5 + 0.7 * appear, 0.5 + 0.7 * appear) * EFFECT_SCALE
			burst_flash.modulate.a = 1.0 - appear * 0.5
			burst_flash.scale = Vector2(0.3 + 1.2 * appear, 0.3 + 1.2 * appear) * EFFECT_SCALE
		else:
			var fade := (burst_t - 0.3) / 0.7
			target_wisp.modulate.a = 1.0 - fade
			target_wisp.scale = Vector2(1.2 - 0.4 * fade, 1.2 - 0.4 * fade) * EFFECT_SCALE
			burst_flash.modulate.a = 0.5 * (1.0 - fade)

	# 完成
	else:
		_finish_playback()


func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var one_minus_t := 1.0 - t
	return one_minus_t * one_minus_t * p0 + 2.0 * one_minus_t * t * p1 + t * t * p2


func _quadratic_bezier_tangent(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	return 2.0 * (1.0 - t) * (p1 - p0) + 2.0 * t * (p2 - p1)


func _set_trail_direction(travel_direction: Vector2) -> void:
	if _trail_process_material == null or travel_direction.is_zero_approx():
		return
	var trail_direction := -travel_direction.normalized()
	_trail_process_material.direction = Vector3(trail_direction.x, trail_direction.y, 0.0)


func _finish_playback() -> void:
	_active = false
	set_process(false)
	visible = false
	var cb := _release_cb
	_release_cb = Callable()
	if cb.is_valid():
		cb.call()

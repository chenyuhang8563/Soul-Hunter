class_name AttackCamera2D
extends Camera2D

@export var attack_shake_duration := 0.16
@export var attack_shake_horizontal_amplitude := 5.5
@export var attack_shake_vertical_amplitude := 3.0
@export var fast_curve_weight := 1.1
@export var sway_curve_weight := 0.8
@export var fast_curve: Curve
@export var sway_curve: Curve

var _base_offset := Vector2.ZERO
var _shake_time := 0.0
var _shake_duration_runtime := 0.0
var _shake_intensity := 0.0
var _fast_phase := 0.08
var _sway_phase := 0.17
var _kick_offset := Vector2.ZERO

func _ready() -> void:
	_base_offset = offset
	if fast_curve == null:
		fast_curve = _build_fast_curve()
	if sway_curve == null:
		sway_curve = _build_sway_curve()

func _process(delta: float) -> void:
	if _shake_duration_runtime <= 0.0 or _shake_intensity <= 0.0 or not enabled:
		if offset != _base_offset:
			offset = _base_offset
		return
	_shake_time += delta
	var normalized_time := minf(_shake_time / _shake_duration_runtime, 1.0)
	var envelope := pow(maxf(0.0, 1.0 - normalized_time), 0.9)
	var fast_time := fposmod(normalized_time + _fast_phase, 1.0)
	var sway_time := fposmod(normalized_time + _sway_phase, 1.0)
	var x_value := _sample_curve(fast_curve, fast_time) * fast_curve_weight
	x_value += _sample_curve(sway_curve, sway_time) * sway_curve_weight
	var vertical_fast_time := fposmod(normalized_time + _fast_phase + 0.23, 1.0)
	var vertical_sway_time := fposmod(normalized_time + _sway_phase + 0.44, 1.0)
	var y_value := _sample_curve(fast_curve, vertical_fast_time) * fast_curve_weight * 0.42
	y_value += _sample_curve(sway_curve, vertical_sway_time) * sway_curve_weight * 0.88
	var kick_weight := pow(maxf(0.0, 1.0 - minf(normalized_time * 3.8, 1.0)), 1.1)
	offset = _base_offset + _kick_offset * kick_weight + Vector2(
		x_value * attack_shake_horizontal_amplitude,
		y_value * attack_shake_vertical_amplitude
	) * envelope * _shake_intensity
	if normalized_time >= 1.0:
		_reset_shake()

func trigger_hit_shake(intensity: float = 1.0, duration_scale: float = 1.0) -> void:
	if fast_curve == null:
		fast_curve = _build_fast_curve()
	if sway_curve == null:
		sway_curve = _build_sway_curve()
	var new_duration := maxf(0.01, attack_shake_duration * maxf(0.1, duration_scale))
	var remaining_duration := maxf(0.0, _shake_duration_runtime - _shake_time)
	_shake_time = 0.0
	_shake_intensity = clampf(maxf(_shake_intensity * 0.6, intensity), 0.0, 2.5)
	_shake_duration_runtime = maxf(new_duration, remaining_duration * 0.55)
	_fast_phase = 0.08
	_sway_phase = 0.17
	_kick_offset = Vector2(
		attack_shake_horizontal_amplitude * 0.42,
		-attack_shake_vertical_amplitude * 0.28
	) * _shake_intensity
	offset = _base_offset + _kick_offset

func _reset_shake() -> void:
	_shake_time = 0.0
	_shake_duration_runtime = 0.0
	_shake_intensity = 0.0
	_kick_offset = Vector2.ZERO
	offset = _base_offset

func _sample_curve(curve: Curve, sample_time: float) -> float:
	if curve == null:
		return 0.0
	return curve.sample_baked(clampf(sample_time, 0.0, 1.0))

func _build_fast_curve() -> Curve:
	var curve := Curve.new()
	curve.min_value = -1.1
	curve.max_value = 1.1
	curve.bake_resolution = 64
	var point_count := 25
	for i in range(point_count):
		var t := float(i) / float(point_count - 1)
		var value := sin(t * TAU * 10.5)
		curve.add_point(Vector2(t, value))
	return curve

func _build_sway_curve() -> Curve:
	var curve := Curve.new()
	curve.min_value = -0.7
	curve.max_value = 0.7
	curve.bake_resolution = 64
	var values := PackedFloat32Array([
		-0.10, -0.28, 0.14, -0.35, -0.26,
		-0.08, 0.04, 0.19, 0.34, -0.27,
		-0.11, -0.20, 0.10, 0.29, -0.06
	])
	for i in range(values.size()):
		var t := float(i) / float(values.size() - 1)
		curve.add_point(Vector2(t, values[i]))
	return curve

extends RefCounted
class_name WaveDirector

const WaveDirectorConfigScript := preload("res://Global/Roguelike/wave_director_config.gd")

var _config: WaveDirectorConfigScript = null

func setup(config: WaveDirectorConfigScript) -> void:
	_config = config

func get_total_waves() -> int:
	if _config == null:
		return 0
	return _config.total_waves

func build_wave_plan(wave_index: int, rng: RandomNumberGenerator) -> Dictionary:
	if _config == null:
		return {}

	var clamped_wave := clampi(wave_index, 1, _config.total_waves)
	var wave_offset := clamped_wave - 1
	var override_entries := _get_override_entries(clamped_wave)
	if not override_entries.is_empty():
		var override_spawns := _build_fixed_spawn_entries(override_entries)
		return _build_wave_plan_dictionary(
			clamped_wave,
			wave_offset,
			_count_spawned_enemies(override_spawns),
			override_spawns
		)

	var generator := rng if rng != null else RandomNumberGenerator.new()
	var target_enemy_count: int = maxi(1, _config.base_enemy_count + wave_offset * _config.enemy_count_per_wave)
	if _config.max_enemy_count > 0:
		target_enemy_count = mini(target_enemy_count, _config.max_enemy_count)
	var eligible_entries := _get_eligible_entries(clamped_wave)
	var spawned_entries := _build_spawn_entries(eligible_entries, target_enemy_count, generator)

	return _build_wave_plan_dictionary(clamped_wave, wave_offset, target_enemy_count, spawned_entries)

func _build_wave_plan_dictionary(wave_index: int, wave_offset: int, enemy_count: int, spawned_entries: Array) -> Dictionary:
	return {
		"wave_index": wave_index,
		"enemy_count": enemy_count,
		"health_multiplier": 1.0 + wave_offset * _config.health_scale_per_wave,
		"attack_multiplier": 1.0 + wave_offset * _config.attack_scale_per_wave,
		"move_speed_multiplier": 1.0 + wave_offset * _config.move_speed_scale_per_wave,
		"spawns": spawned_entries,
	}

func _get_eligible_entries(wave_index: int) -> Array:
	var eligible_entries: Array = []
	for entry in _config.enemy_entries:
		if entry != null and wave_index >= entry.unlock_wave:
			eligible_entries.append(entry)
	return eligible_entries

func _get_override_entries(wave_index: int) -> Array:
	for wave_override in _config.wave_overrides:
		if wave_override == null:
			continue
		if int(wave_override.wave_index) == wave_index:
			return wave_override.spawn_entries
	return []

func _build_spawn_entries(eligible_entries: Array, target_enemy_count: int, rng: RandomNumberGenerator) -> Array:
	if eligible_entries.is_empty():
		return []

	var allocations := {}
	var spawned_total := 0

	while spawned_total < target_enemy_count:
		var selected_entry = _pick_entry(eligible_entries, rng)
		if selected_entry == null:
			break

		allocations[selected_entry] = int(allocations.get(selected_entry, 0)) + 1
		spawned_total += maxi(1, int(selected_entry.base_count_contribution))

	var spawn_entries: Array = []
	for entry in allocations.keys():
		spawn_entries.append({
			"entry": entry,
			"packs": allocations[entry],
			"enemy_count": int(allocations[entry]) * maxi(1, int(entry.base_count_contribution)),
		})

	return spawn_entries

func _build_fixed_spawn_entries(entries: Array) -> Array:
	var allocations := {}
	for entry in entries:
		if entry == null:
			continue
		allocations[entry] = int(allocations.get(entry, 0)) + 1
	return _convert_allocations_to_spawn_entries(allocations)

func _convert_allocations_to_spawn_entries(allocations: Dictionary) -> Array:
	var spawn_entries: Array = []
	for entry in allocations.keys():
		spawn_entries.append({
			"entry": entry,
			"packs": allocations[entry],
			"enemy_count": int(allocations[entry]) * maxi(1, int(entry.base_count_contribution)),
		})
	return spawn_entries

func _count_spawned_enemies(spawn_entries: Array) -> int:
	var total := 0
	for spawn_entry in spawn_entries:
		total += int(spawn_entry.get("enemy_count", 0))
	return total

func _pick_entry(eligible_entries: Array, rng: RandomNumberGenerator):
	var total_weight := 0.0
	for entry in eligible_entries:
		total_weight += maxf(entry.base_weight, 0.0)

	if total_weight <= 0.0:
		return eligible_entries[rng.randi_range(0, eligible_entries.size() - 1)]

	var roll := rng.randf_range(0.0, total_weight)
	var cursor := 0.0
	for entry in eligible_entries:
		cursor += maxf(entry.base_weight, 0.0)
		if roll <= cursor:
			return entry

	return eligible_entries.back()

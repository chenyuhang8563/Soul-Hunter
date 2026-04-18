extends Resource
class_name WaveDirectorConfig

const EnemySpawnEntryScript := preload("res://Global/Roguelike/enemy_spawn_entry.gd")

@export_range(1, 100, 1, "or_greater") var total_waves := 10
@export_range(1, 1000, 1, "or_greater") var base_enemy_count := 3
@export_range(0, 1000, 1, "or_greater") var enemy_count_per_wave := 1
@export_range(0, 1000, 1, "or_greater") var max_enemy_count := 0
@export_range(0.0, 10.0, 0.01, "or_greater") var health_scale_per_wave := 0.1
@export_range(0.0, 10.0, 0.01, "or_greater") var attack_scale_per_wave := 0.05
@export_range(0.0, 10.0, 0.01, "or_greater") var move_speed_scale_per_wave := 0.02
@export var enemy_entries: Array = []
@export var wave_overrides: Array = []

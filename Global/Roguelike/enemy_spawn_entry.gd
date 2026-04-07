extends Resource
class_name EnemySpawnEntry

@export var enemy_scene: PackedScene
@export_range(0.0, 1000.0, 0.1, "or_greater") var base_weight := 1.0
@export_range(1, 100, 1, "or_greater") var unlock_wave := 1
@export_range(1, 100, 1, "or_greater") var base_count_contribution := 1

extends Node

@export var dog_scene: PackedScene
@export var voxel_terrain: VoxelLodTerrain
@export var player: Node3D

@export var min_spawn_distance: float = 20.0
@export var max_spawn_distance: float = 50.0
@export var max_dogs: int = 3
@export var spawn_interval_range: Vector2 = Vector2(40.0, 120.0)

var current_dogs: Array[Node3D] = []
var spawn_timer: Timer

func _ready() -> void:
	spawn_timer = Timer.new()
	spawn_timer.one_shot = true
	add_child(spawn_timer)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	_schedule_next_spawn()

func _schedule_next_spawn() -> void:
	spawn_timer.start(randf_range(spawn_interval_range.x, spawn_interval_range.y))


func _cleanup_dead_dogs() -> void:
	current_dogs = current_dogs.filter(func(d): return is_instance_valid(d))

func _on_spawn_timer_timeout() -> void:
	_cleanup_dead_dogs()
	print("timer fired, current_dogs=", current_dogs.size(), "/", max_dogs)
	if current_dogs.size() < max_dogs:
		_try_spawn_dog()
	_schedule_next_spawn()

func _try_spawn_dog() -> void:
	var voxel_tool = voxel_terrain.get_voxel_tool()
	var angle = randf_range(0, TAU)
	var dist = randf_range(min_spawn_distance, max_spawn_distance)
	var offset = Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	var origin = player.global_position + offset + Vector3(0, 200, 0)

	var result = voxel_tool.raycast(origin, Vector3.DOWN, 400.0)
	if result:
		var hit_world = voxel_terrain.to_global(Vector3(result.position))
		print("origin=", origin, " raw_hit=", result.position, " hit_world=", hit_world, " player=", player.global_position)
		var dog = dog_scene.instantiate()
		add_child(dog)
		dog.global_position = hit_world + Vector3(0, 0.5, 0)
		dog.voxel_terrain = voxel_terrain
		current_dogs.append(dog)

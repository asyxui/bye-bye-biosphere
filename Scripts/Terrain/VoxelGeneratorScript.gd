@tool
extends VoxelGeneratorScript

const channel : int = VoxelBuffer.CHANNEL_TYPE

var block_type_noise_gen := FastNoiseLite.new()
var terrain_noise_gen := FastNoiseLite.new()
var cave_noise_gen := FastNoiseLite.new()
var biome_noise_gen := FastNoiseLite.new()

const BLOCK_TYPE_FREQUENCY = 1.0 / 64.0
const TERRAIN_FREQUENCY = 1.0 / 80.0
const CAVE_FREQUENCY = 1.0 / 250.0
const BIOME_FREQUENCY = 1.0 / 30.0

const CAVE_CUTOFF = 0.3

const BLOCK_AIR := 0
const BLOCK_STONE := 1
const BLOCK_IRON_ORE := 2
const IRON_ORE_NOISE_THRESHOLD := 0.35
const STARTER_IRON_CENTER := Vector2(32.0, 0.0)
const STARTER_IRON_RADIUS := 10.0
const STARTER_IRON_DEPTH := 12.0

var biome_cache: Array = []
var _performance_mutex := Mutex.new()
var _performance_capture_enabled := false
var _performance_statistics: Dictionary = {}
var _noise_prepared := false

func _init() -> void:
	prepare_noise()

func _ready():
	prepare_noise()

func _get_used_channels_mask() -> int:
	# only write to the TYPE channel for blocky voxels
	return 1 << channel

func _generate_block(out_buffer: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	if not _noise_prepared:
		prepare_noise()
	if not _performance_capture_enabled:
		_generate_block_without_performance(out_buffer, origin, lod)
		return

	var buffer_size := out_buffer.get_size()
	var scale = 1 << lod
	var biome_started_usec := Time.get_ticks_usec()
	var height_scale := 0.0
	var biome_elapsed_usec := Time.get_ticks_usec() - biome_started_usec
	var generation_started_usec := Time.get_ticks_usec()
	if lod >= 2:
		_generate_block_simple(out_buffer, origin, buffer_size, scale, height_scale)
	else:
		_generate_block_detailed(out_buffer, origin, buffer_size, scale, height_scale)
	var generation_elapsed_usec := Time.get_ticks_usec() - generation_started_usec
	_merge_performance_samples("Biome calculation", biome_elapsed_usec, _generation_label_for_lod(lod), generation_elapsed_usec)


func _generate_block_without_performance(out_buffer: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	var buffer_size := out_buffer.get_size()
	var scale = 1 << lod
	
	# At high LODs, use simplified generation
	if lod >= 2:
		_generate_block_simple(out_buffer, origin, buffer_size, scale, 0.0)
		return
	
	_generate_block_detailed(out_buffer, origin, buffer_size, scale, 0.0)


func _generate_block_detailed(out_buffer: VoxelBuffer, origin: Vector3i, buffer_size: Vector3i, scale: int, height_scale: float) -> void:
	for z in buffer_size.z:
		for x in buffer_size.x:
			var world_x = float(origin.x + x * scale)
			var world_z = float(origin.z + z * scale)
		
			var biome = get_blended_biome(
				world_x * BIOME_FREQUENCY,
				world_z * BIOME_FREQUENCY
			)

			var height = biome["base_height"] + terrain_noise_gen.get_noise_2d(world_x, world_z) * biome["terrain_amplitude"]
			
			if origin.y >= height:
				continue
			
			var max_y = int(min(height - origin.y, buffer_size.y))
			for y in range(max_y):
				var world_y = float(origin.y + y * scale)
				
				if world_y > height: continue	
				if cave_noise_gen.get_noise_3d(world_x, world_y, world_z) >= CAVE_CUTOFF: continue
				
				var block_type = _get_block_type(world_x, world_y, world_z, height)
				out_buffer.set_voxel(block_type, x, y, z, VoxelBuffer.CHANNEL_TYPE)


func _get_block_type(world_x: float, world_y: float, world_z: float, surface_height: float) -> int:
	var starter_patch := Vector2(world_x, world_z).distance_to(STARTER_IRON_CENTER) <= STARTER_IRON_RADIUS
	var exposed_starter_patch := starter_patch and world_y >= surface_height - STARTER_IRON_DEPTH
	var noise_iron := block_type_noise_gen.get_noise_3d(world_x, world_y, world_z) > IRON_ORE_NOISE_THRESHOLD
	return BLOCK_IRON_ORE if exposed_starter_patch or noise_iron else BLOCK_STONE


func reset_performance_statistics() -> void:
	_performance_mutex.lock()
	_performance_statistics = {}
	_performance_mutex.unlock()


func set_performance_capture_enabled(enabled: bool) -> void:
	# Called before the stream is assigned, never while generation jobs are active.
	_performance_capture_enabled = enabled


func get_performance_statistics() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	_performance_mutex.lock()
	for statistic in _performance_statistics.values():
		snapshot.append(statistic.duplicate())
	_performance_mutex.unlock()
	return snapshot


func _merge_performance_samples(biome_label: String, biome_usec: int, generation_label: String, generation_usec: int) -> void:
	_performance_mutex.lock()
	_merge_performance_statistic(biome_label, biome_usec)
	_merge_performance_statistic(generation_label, generation_usec)
	_performance_mutex.unlock()


func _merge_performance_statistic(label: String, elapsed_usec: int) -> void:
	var statistic: Dictionary = _performance_statistics.get(label, _new_performance_statistic(label))
	statistic.total_usec += elapsed_usec
	statistic.count += 1
	statistic.max_usec = maxi(statistic.max_usec, elapsed_usec)
	_performance_statistics[label] = statistic


func _new_performance_statistic(label: String) -> Dictionary:
	return {"label": label, "total_usec": 0, "count": 0, "max_usec": 0}


func _generation_label_for_lod(lod: int) -> String:
	if lod == 0:
		return "LOD 0 detailed"
	if lod == 1:
		return "LOD 1 detailed"
	return "LOD 2+ simplified"

# Simplified generation for distant LODs (2+)
func _generate_block_simple(out_buffer: VoxelBuffer, origin: Vector3i, buffer_size: Vector3i, scale: int, height_scale: float) -> void:
	# At high LODs, skip caves entirely and simplify block selection
	
	# Don't generate far and deep chunks
	if origin.y + buffer_size.y * scale < 0:
		return
	
	for z in buffer_size.z:
		var world_z = float(origin.z + z * scale)
		for x in buffer_size.x:
			var world_x = float(origin.x + x * scale)
			var biome := get_blended_biome(world_x * BIOME_FREQUENCY, world_z * BIOME_FREQUENCY)
			var height: float = biome["base_height"] + terrain_noise_gen.get_noise_2d(world_x, world_z) * biome["terrain_amplitude"]
			
			var max_y = int((height - float(origin.y)) / float(scale))
			max_y = clamp(max_y, 0, buffer_size.y)
			
			var block_type = _get_block_type(world_x, height, world_z, height)

			# Fill entire column below terrain (no caves)
			out_buffer.fill_area(block_type, Vector3(x, 0, z) , Vector3(x + 1, max_y, z + 1), channel)

func prepare_biome_cache():
	if not biome_cache.is_empty():
		return

	for biome in Biomes.biomes.keys():
		biome_cache.append({
			"id": biome,
			"center": Biomes.get_property(biome, "threshold_center"),
			"base_height": Biomes.get_property(biome, "base_height"),
			"terrain_amplitude": Biomes.get_property(biome, "terrain_amplitude")
		})

func get_blended_biome(x: float, z: float) -> Dictionary:
	prepare_biome_cache()

	var t = (biome_noise_gen.get_noise_2d(x, z) + 1.0) * 0.5

	var primary_biome = null
	var secondary_biome = null
	var best_weight = -INF
	var secondary_weight = -INF

	for biome in biome_cache:
		var dist = abs(t - biome["center"])
		var weight = 1.0 / pow(dist + 0.001, 2)

		if weight > best_weight:
			secondary_weight = best_weight
			secondary_biome = primary_biome

			best_weight = weight
			primary_biome = biome

		elif weight > secondary_weight:
			secondary_weight = weight
			secondary_biome = biome

	var total = best_weight + secondary_weight
	var ta = best_weight / total
	var tb = secondary_weight / total

	return {
		"base_height": (
			primary_biome["base_height"] * ta +
			secondary_biome["base_height"] * tb
		),
		"terrain_amplitude": (
			primary_biome["terrain_amplitude"] * ta +
			secondary_biome["terrain_amplitude"] * tb
		)
	}

func prepare_noise():
	if _noise_prepared:
		return
	_noise_prepared = true

	# Block type noise
	block_type_noise_gen.noise_type = FastNoiseLite.TYPE_SIMPLEX
	block_type_noise_gen.seed = 0
	block_type_noise_gen.frequency = BLOCK_TYPE_FREQUENCY
	block_type_noise_gen.fractal_type = FastNoiseLite.FRACTAL_NONE

	# Terrain noise
	terrain_noise_gen.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
	terrain_noise_gen.seed = 0
	terrain_noise_gen.frequency = TERRAIN_FREQUENCY
	terrain_noise_gen.fractal_type = FastNoiseLite.FRACTAL_FBM
	terrain_noise_gen.fractal_octaves = 2
	terrain_noise_gen.fractal_lacunarity = 2.0
	terrain_noise_gen.fractal_gain = 0.5

	# Cave noise
	cave_noise_gen.noise_type = FastNoiseLite.TYPE_SIMPLEX
	cave_noise_gen.seed = 0
	cave_noise_gen.frequency = CAVE_FREQUENCY
	cave_noise_gen.fractal_type = FastNoiseLite.FRACTAL_FBM
	cave_noise_gen.fractal_octaves = 1
	cave_noise_gen.fractal_lacunarity = 2.0
	cave_noise_gen.fractal_gain = 0.5
	
	# Biome noise
	biome_noise_gen.noise_type = FastNoiseLite.TYPE_SIMPLEX
	biome_noise_gen.seed = 0
	biome_noise_gen.frequency = BIOME_FREQUENCY
	biome_noise_gen.fractal_type = FastNoiseLite.FRACTAL_NONE

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
const BLOCK_GREY := 1
const BLOCK_PURPLE := 2

var biome_cache: Array = []

func _ready():
	prepare_noise()

func _get_used_channels_mask() -> int:
	# only write to the TYPE channel for blocky voxels
	return 1 << channel

func _generate_block(out_buffer: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	var buffer_size := out_buffer.get_size()
	var scale = 1 << lod
	
	var height_scale = get_blended_height_scale((origin.x + 8 * scale) * BIOME_FREQUENCY, (origin.z + 8 * scale) * BIOME_FREQUENCY)	
	
	# At high LODs, use simplified generation
	if lod >= 2:
		_generate_block_simple(out_buffer, origin, buffer_size, scale, height_scale)
		return
	
	for z in buffer_size.z:
		for x in buffer_size.x:
			var world_x = float(origin.x + x * scale)
			var world_z = float(origin.z + z * scale)
		
			var height = terrain_noise_gen.get_noise_2d(world_x, world_z) * height_scale
			# normalize biome heights
			height += height_scale / 2
			
			if origin.y >= height:
				continue
			
			var max_y = int(min(height - origin.y, buffer_size.y))
			for y in range(max_y):
				var world_y = float(origin.y + y * scale)
				
				if world_y > height: continue	
				if cave_noise_gen.get_noise_3d(world_x, world_y, world_z) >= CAVE_CUTOFF: continue
				
				var block_val = block_type_noise_gen.get_noise_3d(world_x, world_y, world_z)
				var block_type = BLOCK_PURPLE if block_val > 0.0 else BLOCK_GREY
				out_buffer.set_voxel(block_type, x, y, z, VoxelBuffer.CHANNEL_TYPE)

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
			var height: float = terrain_noise_gen.get_noise_2d(world_x, world_z) * height_scale
			height += height_scale / 2
			
			var max_y = int((height - float(origin.y)) / float(scale))
			max_y = clamp(max_y, 0, buffer_size.y)
			
			var block_val = block_type_noise_gen.get_noise_2d(world_x, world_z)
			var block_type = BLOCK_PURPLE if block_val > 0.0 else BLOCK_GREY

			# Fill entire column below terrain (no caves)
			out_buffer.fill_area(block_type, Vector3(x, 0, z) , Vector3(x + 1, max_y, z + 1), channel)

func prepare_biome_cache():
	if not biome_cache.is_empty():
		return

	for biome in Biomes.biomes.keys():
		biome_cache.append({
			"id": biome,
			"center": Biomes.get_property(biome, "threshold_center"),
			"height_scale": Biomes.get_property(biome, "height_scale")
		})

func get_blended_height_scale(x: float, z: float) -> float:
	prepare_biome_cache()
	
	var t = (biome_noise_gen.get_noise_2d(x, z) + 1.0) / 2.0

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

	return (
		primary_biome["height_scale"] * ta +
		secondary_biome["height_scale"] * tb
	)

func prepare_noise():
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

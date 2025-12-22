@tool
extends VoxelGeneratorScript

const channel : int = VoxelBuffer.CHANNEL_TYPE

var block_type_noise_gen := FastNoiseLite.new()
var terrain_noise_gen := FastNoiseLite.new()
var cave_noise_gen := FastNoiseLite.new()

const BLOCK_TYPE_FREQUENCY = 1.0 / 64.0
const TERRAIN_FREQUENCY = 1.0 / 80.0
const CAVE_FREQUENCY = 1.0 / 250

const BLOCK_AIR := 0
const BLOCK_GREY := 1
const BLOCK_PURPLE := 2


func _ready():
	prepare_noise()

func _get_used_channels_mask() -> int:
	# only write to the TYPE channel for blocky voxels
	return 1 << channel

func _generate_block(out_buffer: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	var buffer_size := out_buffer.get_size()
	var scale = 1 << lod
	
	# Critical: At high LODs, use simplified generation
	if lod >= 2:
		_generate_block_simple(out_buffer, origin, buffer_size, scale)
		return
	
	# Pre-calculate heights to avoid redundant terrain noise calls
	var heights := PackedFloat32Array()
	heights.resize(buffer_size.x * buffer_size.z)
	var has_terrain := false
	
	for z in buffer_size.z:
		var world_z = float(origin.z + z * scale)
		for x in buffer_size.x:
			var world_x = float(origin.x + x * scale)
			var height := terrain_noise_gen.get_noise_2d(world_x, world_z) * 20.0
			heights[z * buffer_size.x + x] = height
			if height > origin.y:
				has_terrain = true
	
	# Early exit if entire chunk is above terrain
	if not has_terrain:
		return
	
	for z in buffer_size.z:
		for x in buffer_size.x:
			var world_x = float(origin.x + x * scale)
			var world_z = float(origin.z + z * scale)
		
			var height := terrain_noise_gen.get_noise_2d(world_x, world_z) * 20.0
			
			if origin.y >= height:
				continue
			
			var max_y = int(min(height - origin.y, buffer_size.y))
			for y in range(max_y):
				var world_y = float(origin.y + y * scale)
				
				if world_y > height:
					continue
					
				var cave_val = 0.0
				if lod < 3:
					cave_val = cave_noise_gen.get_noise_3d(world_x, world_y, world_z)
					
				if cave_val < 0.30:
					var block_val = block_type_noise_gen.get_noise_3d(world_x, world_y, world_z)
					var block_type = BLOCK_PURPLE if block_val > 0 else BLOCK_GREY
					if block_type != BLOCK_AIR:
						out_buffer.set_voxel(block_type, x, y, z, VoxelBuffer.CHANNEL_TYPE)

# Simplified generation for distant LODs (2+)
func _generate_block_simple(out_buffer: VoxelBuffer, origin: Vector3i, buffer_size: Vector3i, scale: int) -> void:
	# At high LODs, skip caves entirely and simplify block selection
	
	for z in buffer_size.z:
		var world_z = float(origin.z + z * scale)
		for x in buffer_size.x:
			var world_x = float(origin.x + x * scale)
			var height := terrain_noise_gen.get_noise_2d(world_x, world_z) * 20.0
			
			# Key fix: Calculate max_y in voxel space, not world space
			var max_y = int((height - float(origin.y)) / float(scale))
			max_y = clamp(max_y, 0, buffer_size.y)
			
			# Sample block type once per column using 2D noise for speed
			var block_val = block_type_noise_gen.get_noise_2d(world_x, world_z)
			var block_type = BLOCK_PURPLE if block_val > 0.0 else BLOCK_GREY
			
			# Fill entire column below terrain (no caves)
			for y in max_y:
				out_buffer.set_voxel(block_type, x, y, z, channel)

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

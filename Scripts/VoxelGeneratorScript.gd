extends VoxelGeneratorScript

const channel = VoxelBuffer.CHANNEL_TYPE
var noise = FastNoiseLite.new()

func _get_used_channels_mask() -> int:
	return 1 << channel

func _generate_block(buffer: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	for x in range(buffer.get_size().x):
		for y in range(buffer.get_size().y):
			for z in range(buffer.get_size().z):
				var world_x = origin.x + x
				var world_y = origin.y + y
				var world_z = origin.z + z
				
				var materialNoise = noise.get_noise_3d(world_x, world_y, world_z)
				var AirNoise = noise.get_noise_3d(world_x, world_y, world_z)
				var vareNoise = noise.get_noise_3d(world_x, world_y, world_z)
				var biomeNoise = noise.get_noise_2d(world_x, world_y)
				
				
				
				buffer.set_voxel(1, x, y, z, VoxelBuffer.CHANNEL_TYPE)

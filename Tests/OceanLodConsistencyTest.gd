extends "res://Tests/TestCase.gd"

const WATER_VOXEL := 8
const MAX_TEST_LOD := 5

func _run() -> void:
	var world_scene: PackedScene = load("res://Scenes/Root.tscn")
	var world := world_scene.instantiate()
	var terrain: VoxelLodTerrain = world.get_node("Terrain")
	var generator: VoxelGenerator = terrain.generator
	var ocean_position := _find_ocean_position(generator)
	check(ocean_position != Vector2i(2147483647, 2147483647), "Could not find an ocean column")
	if failed:
		world.queue_free()
		return

	for lod in range(MAX_TEST_LOD + 1):
		var lod_scale := 1 << lod
		var origin := Vector3i(
			floori(float(ocean_position.x) / lod_scale) * lod_scale,
			-2 * lod_scale,
			floori(float(ocean_position.y) / lod_scale) * lod_scale
		)
		var buffer := VoxelBuffer.new()
		buffer.create(1, 4, 1)
		generator.generate_block(buffer, origin, lod)

		check(
			buffer.get_voxel(0, 1, 0, VoxelBuffer.CHANNEL_TYPE) == WATER_VOXEL,
			"LOD %d has no water directly below sea level at %s" % [lod, origin]
		)
		check(
			buffer.get_voxel(0, 2, 0, VoxelBuffer.CHANNEL_TYPE) != WATER_VOXEL,
			"LOD %d places water at or above sea level" % lod
		)

	_check_ocean_cave_seal(generator, ocean_position)
	world.queue_free()

func _check_ocean_cave_seal(generator: VoxelGenerator, ocean_position: Vector2i) -> void:
	generator.noise_cave_cutoff = -2.0
	var buffer := VoxelBuffer.new()
	buffer.create(1, 192, 1)
	var origin := Vector3i(ocean_position.x, -128, ocean_position.y)
	generator.generate_block(buffer, origin, 0)

	var seabed_index := -1
	for y in range(127, -1, -1):
		if buffer.get_voxel(0, y, 0, VoxelBuffer.CHANNEL_TYPE) != WATER_VOXEL:
			seabed_index = y
			break
	check(seabed_index >= 0, "Ocean column has no seabed")
	if seabed_index < 0:
		return

	var seal_depth := floori(generator.cave_ocean_seal_depth)
	for offset in range(seal_depth):
		var y := seabed_index - offset
		if y < 0:
			break
		check(
			buffer.get_voxel(0, y, 0, VoxelBuffer.CHANNEL_TYPE) != 0,
			"Ocean cave breached the seabed seal at depth %d" % offset
		)

	var deep_cave_found := false
	for y in range(seabed_index - seal_depth - 2, -1, -1):
		if buffer.get_voxel(0, y, 0, VoxelBuffer.CHANNEL_TYPE) == 0:
			deep_cave_found = true
			break
	check(deep_cave_found, "Caves did not resume below the ocean seal")

func _find_ocean_position(generator: VoxelGenerator) -> Vector2i:
	for z in range(-4096, 4097, 128):
		for x in range(-4096, 4097, 128):
			if generator.get_biome_at(Vector3(x, 0, z)).begins_with("Ocean"):
				return Vector2i(x, z)
	return Vector2i(2147483647, 2147483647)

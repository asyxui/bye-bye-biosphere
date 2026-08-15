extends Node3D

var _initialized: bool = false


func get_fresh_voxel_tool() -> VoxelTool:
	var terrain = get_voxel_terrain()
	if not terrain:
		CustomLogger.log_error("Cannot get voxel tool: terrain not found")
		return null

	var tool = terrain.get_voxel_tool()
	if not tool:
		CustomLogger.log_error("Terrain failed to provide voxel tool")
		return null

	return tool


func get_voxel_terrain() -> VoxelLodTerrain:
	var terrain = get_tree().root.find_child("Terrain", true, false)
	if not terrain:
		CustomLogger.log_error("Terrain node not found in scene")
		return null
	return terrain


func ensure_voxel_systems_initialized() -> bool:
	if _initialized:
		return true

	_init_voxel_systems()
	return _initialized


func _init_voxel_systems() -> void:
	if _initialized:
		return

	# Find terrain and verify we can get a tool
	var voxelTerrain = get_voxel_terrain()
	if not voxelTerrain:
		CustomLogger.log_error("Terrain not found")
		return

	if not voxelTerrain.get_voxel_tool():
		CustomLogger.log_error("Failed to get voxel tool from terrain")
		return

	_initialized = true
	CustomLogger.log_info("Voxel systems initialized")


func ensure_initialized() -> bool:
	if not _initialized:
		return false

	var terrain = get_voxel_terrain()
	if not terrain:
		_initialized = false
		return false

	if not terrain.get_voxel_tool():
		return false

	return true


## Wait for the player's terrain area to finish meshing.
func wait_for_terrain_ready() -> bool:
	var terrain = get_voxel_terrain()
	if not terrain:
		CustomLogger.log_error("Cannot wait for terrain: terrain not found")
		return false

	var player = get_tree().root.find_child("Player", true, false)
	if not player:
		CustomLogger.log_error("Cannot wait for terrain: player not found")
		return false

	var player_pos = player.global_position
	var player_local = terrain.to_local(player_pos)
	var local_half_extent = Vector3(16, 16, 16)
	var local_min = player_local - local_half_extent
	var local_max = player_local + local_half_extent
	var player_area = AABB(local_min, local_max - local_min)
	var fall_distance_world = 200.0
	var fall_area = AABB(
		terrain.to_local(player_pos + Vector3(-4, -fall_distance_world, -4)),
		terrain.to_local(player_pos + Vector3(4, 0, 4)) - terrain.to_local(player_pos + Vector3(-4, -fall_distance_world, -4))
	)
	var safety_lod = maxi(0, terrain.lod_count - 1)
	var deadline = Time.get_ticks_msec() + 100000
	var last_performance_snapshot_msec := 0
	CustomLogger.log_info("Waiting for terrain areas: player=%s local=%s nearby=%s fall_corridor=%s lod=%d" % [player_pos, player_local, player_area, fall_area, safety_lod])

	while Time.get_ticks_msec() < deadline:
		var now_msec := Time.get_ticks_msec()
		if PerformanceTracker.is_display_enabled() and now_msec - last_performance_snapshot_msec >= 250:
			VoxelStreamManager.update_generator_performance_for_timer(PerformanceTracker.get_latest_timer("Loading").get("id", 0))
			last_performance_snapshot_msec = now_msec
		if terrain.is_area_meshed(player_area, 0) and terrain.is_area_meshed(fall_area, safety_lod):
			VoxelStreamManager.update_generator_performance_for_timer(PerformanceTracker.get_latest_timer("Loading").get("id", 0))
			CustomLogger.log_info("Terrain area around player is ready")
			return true
		await get_tree().process_frame

	CustomLogger.log_warn("Terrain area did not finish meshing before the 100 second deadline. Statistics: %s" % terrain.get_statistics())
	VoxelStreamManager.update_generator_performance_for_timer(PerformanceTracker.get_latest_timer("Loading").get("id", 0))
	return false

func _destroy(origin: Vector3, direction: Vector3):
	if not ensure_initialized():
		return

	var voxelTool = get_fresh_voxel_tool()
	if not voxelTool:
		return

	var hit = voxelTool.raycast(origin, direction, 100)

	if hit != null:
		voxelTool.channel = VoxelBuffer.CHANNEL_TYPE
		voxelTool.value = 0

		var drops: Array[int] = []
		var coordsWithDrops: Array[Vector3] = []
		var coordsWorld = sphere_coords(hit.position, 1, 2)

		for i in range(0, coordsWorld.size()):
			var type: int = voxelTool.get_voxel(coordsWorld[i])
			if type != 0:
				drops.append(type)
				coordsWithDrops.append(coordsWorld[i])

		voxelTool.do_sphere(hit.position, 2)
		await get_tree().create_timer(0.2).timeout

		for i in range(coordsWithDrops.size()):
			var coord: Vector3 = coordsWithDrops[i]
			# coord.y += 1
			drop_item(drops[i], coord)
		BiosphereManager.record_raw_material_extracted(drops.size())

func save_map() -> void:
	# Delegate voxel save to VoxelStreamManager
	var voxel_stream_manager = get_node("/root/VoxelStreamManager")
	if voxel_stream_manager:
		voxel_stream_manager.save_voxels_async()


func sphere_coords(center: Vector3, cubeScale: float, radius: int) -> Array[Vector3]:
	var coords: Array[Vector3] = []
	for x in range(-radius, radius):
		for y in range(-radius, radius):
			for z in range(-radius, radius):
				var pos = Vector3(cubeScale * x, cubeScale * y, cubeScale * z)
				if (pos.length() <= radius * cubeScale - 0.001):
					coords.append(pos + center)
	return coords

## Structure dismantling uses the same ray as terrain destruction, but resolves
## structure ownership first so machines and conveyors never become terrain
## edits by accident.
func dismantle_structure(origin: Vector3, direction: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * 100.0)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false
	var structure := _find_structure_ancestor(result.get("collider"))
	if structure == null:
		return false
	if structure.get("machine_type") != null:
		return MachineManager.remove_machine(structure)
	if structure.name == "ConveyorBelt" or structure.has_meta("conveyor_belt_object"):
		return ConveyorConnectionManager.remove_conveyor(structure)
	return false

func _find_structure_ancestor(node: Node) -> Node3D:
	var current := node
	while current != null:
		if current is Node3D and current.is_in_group("structures"):
			return current
		current = current.get_parent()
	return null

func drop_item(type: int, coords: Vector3):
	var item = ItemUtils.item_object_by_type_id(type)
	if item:
		spawn_item_drop(item, coords)

## Spawn a physical drop from an inventory item. This is shared by terrain,
## inventory use, and machines so all drops behave identically on conveyors.
func spawn_item_drop(item: InventoryItem, pos: Vector3, parent: Node = null, quantity: int = 1, isGlobal: bool = false) -> Node3D:
	if item == null:
		return null
	var newDrop = preload("res://Resources/Items/Drop.tscn").instantiate()
	var mesh = newDrop.get_child(0).get_child(0)
	var newMat = mesh.mesh.surface_get_material(0).duplicate()

	mesh.set_surface_override_material(0, newMat)

	newDrop.dropData = item
	newDrop.quantity = maxi(1, quantity)
	newMat.albedo_color = newDrop.dropData.dropColor
	newDrop.get_child(0).add_to_group("Collectibles")
	get_voxel_terrain().add_child(newDrop)
	if !isGlobal:
		var offset = 0.5
		pos.x += offset
		pos.y += offset
		pos.z += offset
		newDrop.position = pos
	else:
		newDrop.global_position = pos

	return newDrop

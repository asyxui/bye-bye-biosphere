## Manages voxel terrain operations and modifications
extends Node3D

var _initialized: bool = false


## Get a fresh voxel tool from the current terrain
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


## Get the voxel terrain node (find it fresh each time)
func get_voxel_terrain() -> VoxelLodTerrain:
	var terrain = get_tree().root.find_child("Terrain", true, false)
	if not terrain:
		CustomLogger.log_error("Terrain node not found in scene")
		return null
	return terrain


## Force initialization of voxel systems (called after terrain is guaranteed to exist)
func initialize_voxel_systems() -> void:
	if _initialized:
		return
	
	_init_voxel_systems()


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
	
	# Connect to stream reconfiguration signal
	var voxel_stream_manager = get_node("/root/VoxelStreamManager")
	if voxel_stream_manager and not voxel_stream_manager.stream_reconfigured.is_connected(_on_stream_reconfigured):
		voxel_stream_manager.stream_reconfigured.connect(_on_stream_reconfigured)
	
	_initialized = true
	CustomLogger.log_info("Voxel systems initialized")


## Ensure voxel systems are initialized before use
func ensure_initialized() -> bool:
	if not _initialized:
		return false
	
	# Verify terrain still exists (might be invalid after scene reload)
	var terrain = get_voxel_terrain()
	if not terrain:
		_initialized = false
		return false
	
	# Verify we can get a fresh tool from terrain
	if not terrain.get_voxel_tool():
		return false
	
	return true



## Reinitialize voxel tool when stream is reconfigured
func _on_stream_reconfigured() -> void:
	CustomLogger.log_info("Stream reconfigured signal received - voxel tools will be freshly generated on next use")


## Wait for terrain to be ready (stream configured)
func wait_for_terrain_ready() -> void:
	# Simple wait for stream to be configured
	# Chunks will stream in naturally as the scene renders
	var max_wait_time = 3.0
	var elapsed_time = 0.0
	var voxel_stream_manager = get_node("/root/VoxelStreamManager")
	
	while elapsed_time < max_wait_time:
		if voxel_stream_manager and voxel_stream_manager.get_state() == voxel_stream_manager.State.LOADED:
			CustomLogger.log_info("Voxel stream ready")
			return
		
		await get_tree().create_timer(0.1).timeout
		elapsed_time += 0.1
	
	CustomLogger.log_warn("Voxel stream took longer than expected to initialize")


## Wait for minimum terrain to stabilize around the player
## Uses raycasting to detect terrain as soon as it's solid under the player
func wait_for_terrain_stabilization() -> void:
	# Uncomment this next line to test faster loading
	# return
	var terrain = get_voxel_terrain()
	if not terrain:
		CustomLogger.log_warn("Cannot wait for stabilization: terrain not found")
		return
	
	var player = get_tree().root.find_child("Player", true, false)
	if not player:
		CustomLogger.log_warn("Cannot wait for stabilization: player not found")
		return
	
	var player_pos = player.global_position
	var max_wait_time = 100.0
	var elapsed = 0.0
	
	while elapsed < max_wait_time:
		# Use Physics3D raycast with proper distance limit
		var query = PhysicsRayQueryParameters3D.create(player_pos, player_pos + Vector3.DOWN * 200)
		query.collide_with_areas = false
		query.exclude = [player]
		var result = get_world_3d().direct_space_state.intersect_ray(query)
		
		if result:
			var check_pos = result.position
			
			CustomLogger.log_info("Terrain detected after %.1fs at (%.0f, %.0f, %.0f), releasing player!" % [elapsed, check_pos.x, check_pos.y, check_pos.z])
			break
		
		await get_tree().create_timer(0.05).timeout  # More frequent checks with less work per check
		elapsed += 0.05
	
	CustomLogger.log_warn("Terrain check timed out after %.1f seconds" % [elapsed])

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
		var coords = sphere_coords(hit.position, 2)
		
		for coord in coords: 
			var type: int = voxelTool.get_voxel(coord)
			if type != 0:	
				drops.append(type)
				coordsWithDrops.append(coord)
		
		voxelTool.do_sphere(hit.position, 2)
		await get_tree().create_timer(0.2).timeout 
		
		for i in range(coordsWithDrops.size()): 
			var coord: Vector3 = coordsWithDrops[i]
			coord.y += 1
			drop_item(drops[i], coord)

func save_map() -> void:
	# Delegate voxel save to VoxelStreamManager
	# This is now async and will emit save_complete signal when done
	var voxel_stream_manager = get_node("/root/VoxelStreamManager")
	if voxel_stream_manager:
		voxel_stream_manager.save_voxels_async()


func sphere_coords(center: Vector3, radius: int) -> Array[Vector3]:
	var coords: Array[Vector3] = []
	for x in range(-radius, radius):
		for y in range(-radius, radius):
			for z in range(-radius, radius):
				var pos = Vector3(x, y, z)
				if (pos.length() <= radius):
					coords.append(pos + center)
	return coords
	
	
func drop_item(type: int, coords: Vector3) -> void:
	var voxelTerrain = get_voxel_terrain()
	if not voxelTerrain:
		return
	
	var item: Node3D
	match type:
		1:
			item = preload("res://Assets/Items/Rock.tscn").instantiate()
		2:
			item = preload("res://Assets/Items/PurpleOre.tscn").instantiate()
		_:
			return
	
	item.global_position = coords
	voxelTerrain.add_child(item)
	

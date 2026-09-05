extends Node

signal world_loaded
signal world_created
signal world_load_failed(error: String)

var _is_restoring = false


func _ready() -> void:
	CustomLogger.log_info("GameStateRestoreManager initialized")


func initialize_startup_world() -> bool:
	GameStateManager.start_loading("Starting World...")

	# Load saved slot or create default world
	var root = get_tree().root
	if root.has_meta("current_save_slot"):
		var slot_id = root.get_meta("current_save_slot")
		CustomLogger.log_info("Loading save slot: %s" % slot_id)
		return await _load_existing_world(slot_id)
	else:
		return await _auto_load_default_world()


func transition_to_world(new_slot_id: String) -> bool:
	var current_slot = get_tree().root.get_meta("current_save_slot") if get_tree().root.has_meta("current_save_slot") else null
	if current_slot == new_slot_id:
		return true

	GameStateManager.start_loading("Loading World...", "Current world saved")

	# Save current world first
	if current_slot:
		CustomLogger.log_info("Saving current world: %s" % current_slot)
		if not await SaveManager.save_game(current_slot):
			return _fail_restore("Failed to save current world: %s" % current_slot)
		PerformanceTracker.checkpoint(_loading_timer_id(), "World stream configured")

	if not await _unload_current_world():
		return _fail_restore("Failed to unload current world")

	return await _load_existing_world(new_slot_id)


func reset_current_world() -> bool:
	GameStateManager.start_loading("Resetting World...")
	var voxel_stream_manager = get_node_or_null("/root/VoxelStreamManager")
	if not voxel_stream_manager:
		return _fail_restore("VoxelStreamManager not found")

	voxel_stream_manager.reset_world_async()
	var reset_result = await voxel_stream_manager.reset_complete
	if not reset_result[0]:
		return _fail_restore("Failed to reset world: %s" % reset_result[1])

	# Keep loading active while the new scene is instantiated. Startup will
	# restart the operation name and synchronize the new LoadingScreen.
	get_tree().reload_current_scene()
	return true


func _unload_current_world() -> bool:
	SaveManager.clear_all_saveables()

	var voxel_stream_manager = get_node_or_null("/root/VoxelStreamManager")
	if not voxel_stream_manager:
		return false
	return await voxel_stream_manager.unload_stream()


func _load_existing_world(slot_id: String) -> bool:
	if _is_restoring:
		return _fail_restore("Game restore already in progress")

	_is_restoring = true
	GameStateManager.set_loading_progress(5)

	# Validate the prototype save schema before touching the voxel stream or
	# any live world state.
	var save_data = SaveManager.load_game_data(slot_id)
	if save_data == null:
		return _fail_restore(SaveManager.get_last_load_error())

	GameStateManager.set_loading_progress(15)

	# Configure voxel stream for this slot (must do this before loading save data)
	var voxel_stream_manager = get_node("/root/VoxelStreamManager")
	if not voxel_stream_manager:
		return _fail_restore("VoxelStreamManager not found")
	if not await voxel_stream_manager.configure_stream(slot_id):
		return _fail_restore("Failed to configure voxel stream for slot: %s" % slot_id)
	PerformanceTracker.checkpoint(_loading_timer_id(), "Save state restored")

	GameStateManager.set_loading_progress(25)

	var map_manager = _get_map_manager()
	if not map_manager:
		return false
	if not map_manager.ensure_voxel_systems_initialized():
		return _fail_restore("Failed to initialize voxel systems")

	GameStateManager.set_loading_progress(50)

	if not SaveManager.restore_game_state(save_data):
		return _fail_restore("Failed to restore game state for slot: %s" % slot_id)
	PerformanceTracker.checkpoint(_loading_timer_id(), "Initial terrain generation")

	GameStateManager.set_loading_progress(70)

	var terrain_ready: bool = await map_manager.wait_for_terrain_ready()
	_attach_generator_performance()
	if not terrain_ready:
		return _fail_restore("Terrain did not become ready")
	GameStateManager.set_loading_progress(90)

	get_tree().root.set_meta("current_save_slot", slot_id)
	GameStateManager.finish_loading()
	_is_restoring = false
	world_loaded.emit()
	return true


func _auto_load_default_world() -> bool:
	var voxel_stream_manager = get_node("/root/VoxelStreamManager")
	var default_slot_path = SaveManager.get_slot_directory("default")
	var slot_exists = DirAccess.dir_exists_absolute(default_slot_path)

	if slot_exists:
		CustomLogger.log_info("Loading default world")
		return await _load_existing_world("default")
	else:
		CustomLogger.log_info("Creating default world")
		if SaveManager.create_slot("default") and await voxel_stream_manager.configure_stream("default"):
			PerformanceTracker.checkpoint(_loading_timer_id(), "Initial terrain generation")
			GameStateManager.set_loading_progress(15)
			return await _finalize_new_world("default")
		else:
			return _fail_restore("Failed to create default world")


func _finalize_new_world(slot_id: String) -> bool:
	var map_manager = _get_map_manager()
	if not map_manager:
		return false

	if not map_manager.ensure_voxel_systems_initialized():
		return _fail_restore("Failed to initialize voxel systems")

	GameStateManager.set_loading_progress(50)

	var terrain_ready: bool = await map_manager.wait_for_terrain_ready()
	_attach_generator_performance()
	if not terrain_ready:
		return _fail_restore("Terrain did not become ready")
	PerformanceTracker.checkpoint(_loading_timer_id(), "Initial world saved")
	GameStateManager.set_loading_progress(90)

	GameStateManager.set_loading_progress(95)
	if not await SaveManager.save_game(slot_id):
		return _fail_restore("Failed to save initial world: %s" % slot_id)

	GameStateManager.finish_loading()

	world_created.emit()
	return true


func _get_map_manager() -> Node:
	var map_manager = get_tree().root.find_child("MapManager", true, false)
	if not map_manager:
		_fail_restore("MapManager not found in scene tree")
		return null
	return map_manager


func _fail_restore(error: String) -> bool:
	_is_restoring = false
	GameStateManager.finish_loading(false)
	push_error(error)
	world_load_failed.emit(error)
	return false


func _loading_timer_id() -> int:
	return PerformanceTracker.get_latest_timer("Loading").get("id", 0)


func _attach_generator_performance() -> void:
	var voxel_stream_manager = get_node_or_null("/root/VoxelStreamManager")
	if voxel_stream_manager:
		voxel_stream_manager.update_generator_performance_for_timer(_loading_timer_id())

## Manages game state restoration and world initialization
## Uses SaveManager for loading game data after voxel stream is ready
extends Node

signal world_loaded
signal world_created
signal world_load_failed(error: String)

var _is_restoring = false


func _ready() -> void:
	CustomLogger.log_info("GameStateRestoreManager initialized")


## Initialize world on startup - either load saved slot or create default
func initialize_startup_world() -> bool:
	_start_loading_sequence("Starting World...")
	
	# Load saved slot or create default world
	var root = get_tree().root
	if root.has_meta("current_save_slot"):
		var slot_id = root.get_meta("current_save_slot")
		CustomLogger.log_info("Loading save slot: %s" % slot_id)
		return await restore_game_state(slot_id)
	else:
		return await _auto_load_default_world()


## Transition from current world to a new one
## Saves current world, unloads it, then loads the new one
func transition_to_world(new_slot_id: String) -> bool:
	_start_loading_sequence("Loading World...")
	
	# Save current world first
	var current_slot = get_tree().root.get_meta("current_save_slot") if get_tree().root.has_meta("current_save_slot") else null
	if current_slot:
		CustomLogger.log_info("Saving current world: %s" % current_slot)
		SaveManager.save_game(current_slot)
		var save_result = await SaveManager.save_completed
		if not save_result[0]:
			return _fail_restore("Failed to save current world: %s" % save_result[1])
	
	_update_loading_progress(20)  # Save complete
	
	# Unload current world
	await _unload_current_world()
	
	_update_loading_progress(30)  # Unload complete
	
	# Load new world (without starting a new loading sequence)
	return await _restore_world(new_slot_id)


## Unload current world - clear terrain and reset state
func _unload_current_world() -> void:
	# Clear all saveable components
	SaveManager.clear_all_saveables()
	
	# Clear the voxel terrain
	var voxel_stream_manager = get_node("/root/VoxelStreamManager")
	if voxel_stream_manager and voxel_stream_manager.voxel_terrain:
		# Set stream to null to unload all chunks
		voxel_stream_manager.voxel_terrain.stream = null
	
	await get_tree().process_frame  # Give a frame for cleanup


## Restore game state after loading a save
## Assumes voxel stream is already configured
func restore_game_state(slot_id: String) -> bool:
	if _is_restoring:
		return _fail_restore("Game restore already in progress")
	
	_is_restoring = true
	_update_loading_progress(5)  # Initialize
	
	# Configure voxel stream for this slot (must do this before loading save data)
	var voxel_stream_manager = get_node("/root/VoxelStreamManager")
	if voxel_stream_manager:
		if not await voxel_stream_manager.configure_stream(slot_id):
			return _fail_restore("Failed to configure voxel stream for slot: %s" % slot_id)
	
	_update_loading_progress(10)  # Stream configured
	
	# Load save data using SaveManager
	var save_data = SaveManager.load_game_data(slot_id)
	if save_data == null:
		return _fail_restore("Failed to load save data for slot: %s" % slot_id)
	
	_update_loading_progress(15)  # Data loaded
	
	# Wait for terrain to be ready
	var map_manager = get_tree().root.find_child("MapManager", true, false)
	if map_manager and map_manager.has_method("wait_for_terrain_ready"):
		await map_manager.wait_for_terrain_ready()
	
	_update_loading_progress(60)  # Terrain ready
	
	# Initialize MapManager voxel systems now that terrain exists
	if map_manager and map_manager.has_method("initialize_voxel_systems"):
		await map_manager.initialize_voxel_systems()
	
	_update_loading_progress(70)  # Voxel systems initialized
	
	# Wait for terrain to stabilize
	_update_loading_progress(75)  # Starting stabilization
	if map_manager and map_manager.has_method("wait_for_terrain_stabilization"):
		await map_manager.wait_for_terrain_stabilization()
	_update_loading_progress(85)  # Stabilization complete
	
	# Restore all game state from save data
	if not SaveManager.restore_game_state(save_data):
		return _fail_restore("Failed to restore game state for slot: %s" % slot_id)
	
	_update_loading_progress(95)  # Game state restored
	
	# Finalize loading - hide screen and unlock player
	_finish_loading_sequence()
	
	_is_restoring = false
	world_loaded.emit()
	return true


## Internal restore function for world transitions (doesn't start/end loading sequence)
func _restore_world(slot_id: String) -> bool:
	# Configure voxel stream for this slot (must do this before loading save data)
	var voxel_stream_manager = get_node("/root/VoxelStreamManager")
	if voxel_stream_manager:
		if not await voxel_stream_manager.configure_stream(slot_id):
			return _fail_restore("Failed to configure voxel stream for slot: %s" % slot_id)
	
	_update_loading_progress(40)  # Stream configured
	
	# Load save data using SaveManager
	var save_data = SaveManager.load_game_data(slot_id)
	if save_data == null:
		return _fail_restore("Failed to load save data for slot: %s" % slot_id)
	
	_update_loading_progress(50)  # Data loaded
	
	# Wait for terrain to be ready
	var map_manager = get_tree().root.find_child("MapManager", true, false)
	if map_manager and map_manager.has_method("wait_for_terrain_ready"):
		await map_manager.wait_for_terrain_ready()
	
	_update_loading_progress(70)  # Terrain ready
	
	# Initialize MapManager voxel systems now that terrain exists
	if map_manager and map_manager.has_method("initialize_voxel_systems"):
		await map_manager.initialize_voxel_systems()
	
	_update_loading_progress(80)  # Voxel systems initialized
	
	# Wait for terrain to stabilize
	if map_manager and map_manager.has_method("wait_for_terrain_stabilization"):
		await map_manager.wait_for_terrain_stabilization()
	_update_loading_progress(85)  # Stabilization complete
	
	# Restore all game state from save data
	if not SaveManager.restore_game_state(save_data):
		return _fail_restore("Failed to restore game state for slot: %s" % slot_id)
	
	_update_loading_progress(95)  # Game state restored
	
	# Finalize loading - hide screen and unlock player
	_finish_loading_sequence()
	
	get_tree().root.set_meta("current_save_slot", slot_id)
	world_loaded.emit()
	return true




## Auto-load the default world on startup
func _auto_load_default_world() -> bool:
	var voxel_stream_manager = get_node("/root/VoxelStreamManager")
	var default_slot_path = SaveManager.get_slot_directory("default")
	var slot_exists = DirAccess.dir_exists_absolute(default_slot_path)
	
	# Check if stream was already configured (e.g., from a reset)
	if slot_exists and voxel_stream_manager.get_state() == voxel_stream_manager.State.LOADED:
		if voxel_stream_manager.current_slot_id == "default":
			return await _finalize_world_load()
	
	if slot_exists:
		CustomLogger.log_info("Loading default world")
		return await restore_game_state("default")
	else:
		CustomLogger.log_info("Creating default world")
		if SaveManager.create_slot("default") and await voxel_stream_manager.configure_stream("default"):
			return await _finalize_world_load()
		else:
			return _fail_restore("Failed to create default world")


## Restore conveyor belts from save data
func _restore_conveyor_belts(conveyor_data: Array[ConveyorBeltObject]) -> void:
	for belt in conveyor_data:
		ConveyorConnectionManager.spawn_conveyor(belt.start, belt.end)


## Finalize world load (common cleanup for both load and create paths)
func _finalize_world_load() -> bool:
	_update_loading_progress(40)  # Terrain initialization starting
	
	var map_manager = get_tree().root.find_child("MapManager", true, false)
	if map_manager:
		if map_manager.has_method("wait_for_terrain_ready"):
			await map_manager.wait_for_terrain_ready()
		if map_manager.has_method("initialize_voxel_systems"):
			await map_manager.initialize_voxel_systems()
	
	_update_loading_progress(70)  # Terrain initialized
	
	# Wait for terrain to stabilize
	_update_loading_progress(75)  # Starting stabilization
	if map_manager and map_manager.has_method("wait_for_terrain_stabilization"):
		await map_manager.wait_for_terrain_stabilization()
	_update_loading_progress(85)  # Stabilization complete
	
	# Finalize loading - hide screen and unlock player
	_finish_loading_sequence()
	
	world_created.emit()
	return true


## Start loading sequence - show loading screen and lock player
func _start_loading_sequence(operation_name: String) -> void:
	# Show loading screen
	var menu_manager = get_tree().root.find_child("MenuManager", true, false)
	if menu_manager and menu_manager.has_node("LoadingScreen"):
		menu_manager.get_node("LoadingScreen").show_loading(operation_name)
	
	# Lock player input during loading
	GameStateManager.start_loading()


## Finish loading sequence - hide loading screen and unlock player
func _finish_loading_sequence() -> void:
	# Unlock player input
	GameStateManager.finish_loading()
	
	# Hide loading screen with fade animation
	var menu_manager = get_tree().root.find_child("MenuManager", true, false)
	if menu_manager and menu_manager.has_method("hide_loading_screen"):
		menu_manager.hide_loading_screen()


func _fail_restore(error: String) -> bool:
	_is_restoring = false
	GameStateManager.finish_loading()
	var menu_manager = get_tree().root.find_child("MenuManager", true, false)
	if menu_manager and menu_manager.has_method("hide_loading_screen"):
		menu_manager.hide_loading_screen()
	push_error(error)
	world_load_failed.emit(error)
	return false


## Update the loading screen progress bar
func _update_loading_progress(percentage: float) -> void:
	var menu_manager = get_tree().root.find_child("MenuManager", true, false)
	if menu_manager and menu_manager.has_node("LoadingScreen"):
		var loading_screen = menu_manager.get_node("LoadingScreen")
		if loading_screen and loading_screen.has_method("set_progress"):
			loading_screen.set_progress(percentage)

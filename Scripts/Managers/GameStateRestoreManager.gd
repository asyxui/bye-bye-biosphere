## Manages game state restoration and world initialization
## Handles loading saves, creating new worlds, and restoring player data
extends Node

signal world_loaded
signal world_created

var slot_manager
var _is_restoring = false


func _ready() -> void:
	var SaveSlotManagerClass = load("res://Scripts/Managers/SaveSlotManager.gd")
	slot_manager = SaveSlotManagerClass.new()
	CustomLogger.log_info("GameStateRestoreManager initialized")


## Initialize world on startup - either load saved slot or create default
func initialize_startup_world() -> void:
	_start_loading_sequence("Starting World...")
	
	# Load saved slot or create default world
	var root = get_tree().root
	if root.has_meta("current_save_slot"):
		var slot_id = root.get_meta("current_save_slot")
		CustomLogger.log_info("Loading save slot: %s" % slot_id)
		await restore_game_state(slot_id)
	else:
		await _auto_load_default_world()


## Restore game state after loading a save
func restore_game_state(slot_id: String) -> void:
	if _is_restoring:
		push_error("Game restore already in progress")
		return
	
	_is_restoring = true
	_update_loading_progress(5)  # Initialize
	
	# Step 1: Ensure save slot is valid
	var slot_path = "user://saves".path_join(slot_id)
	if not DirAccess.dir_exists_absolute(slot_path):
		push_error("Save slot does not exist: %s" % slot_id)
		_is_restoring = false
		return
	
	# Step 2: Configure voxel stream to load from this slot
	var voxel_stream_manager = get_node("/root/VoxelStreamManager")
	if not voxel_stream_manager or not await voxel_stream_manager.configure_stream(slot_id):
		push_error("Failed to configure voxel stream for slot: %s" % slot_id)
		_is_restoring = false
		return
	
	_update_loading_progress(10)  # Stream configured
	
	var SaveDataManagerClass = load("res://Scripts/Managers/SaveDataManager.gd")
	var data_manager = SaveDataManagerClass.new(slot_path)
	
	# Step 3: Restore inventory
	var inventory_data = data_manager.get_inventory()
	var inventory_manager = get_tree().root.find_child("InventoryManager", true, false)
	if inventory_manager and inventory_manager.has_method("load_save_data"):
		inventory_manager.load_save_data(inventory_data)
	
	_update_loading_progress(20)  # Inventory restored
	
	# Step 4: Restore hotbar
	var hotbar_data = data_manager.get_hotbar()
	var tool_manager = get_tree().root.find_child("ToolManager", true, false)
	if tool_manager and tool_manager.has_method("load_save_data"):
		tool_manager.load_save_data(hotbar_data)
	
	_update_loading_progress(30)  # Hotbar restored
	
	# Step 5: Wait for terrain to be ready
	var map_manager = get_tree().root.find_child("MapManager", true, false)
	if map_manager and map_manager.has_method("wait_for_terrain_ready"):
		await map_manager.wait_for_terrain_ready()
	
	_update_loading_progress(60)  # Terrain ready
	
	# Step 5b: Initialize MapManager voxel systems now that terrain exists
	if map_manager and map_manager.has_method("initialize_voxel_systems"):
		await map_manager.initialize_voxel_systems()
	
	_update_loading_progress(70)  # Voxel systems initialized
	
	# Step 5c: Wait for terrain to stabilize (only as long as needed)
	_update_loading_progress(75)  # Starting stabilization
	if map_manager and map_manager.has_method("wait_for_terrain_stabilization"):
		await map_manager.wait_for_terrain_stabilization()
	_update_loading_progress(85)  # Stabilization complete
	
	# Step 6: Restore player position and rotation
	var metadata = data_manager.get_metadata()
	var player = get_tree().root.find_child("Player", true, false)
	if player:
		if "player_position" in metadata:
			var pos_data = metadata["player_position"]
			player.global_position = Vector3(pos_data["x"], pos_data["y"], pos_data["z"])
		
		if "player_rotation" in metadata:
			var rot_data = metadata["player_rotation"]
			player.rotation = Vector3(rot_data["x"], rot_data["y"], rot_data["z"])
	
	_update_loading_progress(90)  # Player position restored
	
	# Step 7: Restore conveyor belts
	var conveyor_data = data_manager.get_conveyor_belts()
	if conveyor_data.size() > 0:
		_restore_conveyor_belts(conveyor_data)
	
	_update_loading_progress(95)  # Conveyor belts restored
	
	# Step 8: Finalize loading - hide screen and unlock player
	_finish_loading_sequence()
	
	_is_restoring = false
	world_loaded.emit()


## Auto-load the default world on startup
func _auto_load_default_world() -> void:
	var voxel_stream_manager = get_node("/root/VoxelStreamManager")
	var default_slot_path = "user://saves/default"
	var slot_exists = DirAccess.dir_exists_absolute(default_slot_path)
	
	# Check if stream was already configured (e.g., from a reset)
	if slot_exists and voxel_stream_manager.get_state() == voxel_stream_manager.State.LOADED:
		if voxel_stream_manager.current_slot_id == "default":
			await _finalize_world_load()
			return
	
	if slot_exists:
		CustomLogger.log_info("Loading default world")
		await restore_game_state("default")
	else:
		CustomLogger.log_info("Creating default world")
		if slot_manager.create_slot("default") and await voxel_stream_manager.configure_stream("default"):
			await _finalize_world_load()
		else:
			push_error("Failed to create default world")


## Restore conveyor belts from save data
func _restore_conveyor_belts(conveyor_data: Array) -> void:
	var root_scene = get_tree().root.get_child(0)
	if not root_scene:
		return
	
	var conveyor_scene = preload("res://Scenes/ConveyorBelt/ConveyorBelt.tscn")
	if not conveyor_scene:
		push_error("Failed to load ConveyorBelt scene")
		return
	
	for conveyor_info in conveyor_data:
		if not conveyor_info is Dictionary:
			continue
		
		# Instantiate the conveyor belt
		var conveyor = conveyor_scene.instantiate()
		if not conveyor:
			continue
		
		# Restore transform
		if "position" in conveyor_info:
			var pos = conveyor_info["position"]
			conveyor.global_position = Vector3(pos["x"], pos["y"], pos["z"])
		
		if "rotation" in conveyor_info:
			var rot = conveyor_info["rotation"]
			conveyor.rotation = Vector3(rot["x"], rot["y"], rot["z"])
		
		if "scale" in conveyor_info:
			var scl = conveyor_info["scale"]
			conveyor.scale = Vector3(scl["x"], scl["y"], scl["z"])
		
		# Add to scene
		root_scene.add_child(conveyor)


## Finalize world load (common cleanup for both load and create paths)
func _finalize_world_load() -> void:
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


## Update the loading screen progress bar
func _update_loading_progress(percentage: float) -> void:
	var menu_manager = get_tree().root.find_child("MenuManager", true, false)
	if menu_manager and menu_manager.has_node("LoadingScreen"):
		var loading_screen = menu_manager.get_node("LoadingScreen")
		if loading_screen and loading_screen.has_method("set_progress"):
			loading_screen.set_progress(percentage)

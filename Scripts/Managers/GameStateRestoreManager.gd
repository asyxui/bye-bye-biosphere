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
	# Show loading screen at startup
	var menu_manager = get_tree().root.find_child("MenuManager", true, false)
	if menu_manager and menu_manager.has_node("LoadingScreen"):
		menu_manager.get_node("LoadingScreen").show_loading("Starting World...")
	
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
	
	var SaveDataManagerClass = load("res://Scripts/Managers/SaveDataManager.gd")
	var data_manager = SaveDataManagerClass.new(slot_path)
	
	# Step 3: Restore inventory
	var inventory_data = data_manager.get_inventory()
	var inventory_manager = get_tree().root.find_child("InventoryManager", true, false)
	if inventory_manager and inventory_manager.has_method("load_save_data"):
		inventory_manager.load_save_data(inventory_data)
	
	# Step 4: Restore hotbar
	var hotbar_data = data_manager.get_hotbar()
	var tool_manager = get_tree().root.find_child("ToolManager", true, false)
	if tool_manager and tool_manager.has_method("load_save_data"):
		tool_manager.load_save_data(hotbar_data)
	
	# Step 5: Wait for terrain to be ready
	var map_manager = get_tree().root.find_child("MapManager", true, false)
	if map_manager and map_manager.has_method("wait_for_terrain_ready"):
		await map_manager.wait_for_terrain_ready()
	
	# Step 5b: Initialize MapManager voxel systems now that terrain exists
	if map_manager and map_manager.has_method("initialize_voxel_systems"):
		await map_manager.initialize_voxel_systems()
	
	# Step 6: Hide loading screen with fade animation
	var menu_manager = get_tree().root.find_child("MenuManager", true, false)
	if menu_manager and menu_manager.has_method("hide_loading_screen"):
		menu_manager.hide_loading_screen()
	
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


## Finalize world load (common cleanup for both load and create paths)
func _finalize_world_load() -> void:
	var map_manager = get_tree().root.find_child("MapManager", true, false)
	if map_manager:
		if map_manager.has_method("wait_for_terrain_ready"):
			await map_manager.wait_for_terrain_ready()
		if map_manager.has_method("initialize_voxel_systems"):
			await map_manager.initialize_voxel_systems()
	
	var menu_manager = get_tree().root.find_child("MenuManager", true, false)
	if menu_manager and menu_manager.has_method("hide_loading_screen"):
		menu_manager.hide_loading_screen()
	
	world_created.emit()

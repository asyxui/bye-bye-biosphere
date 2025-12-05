## Main save game system coordinator
## Handles save/load/create_new_game operations with async support
extends Node

class_name SaveGameManager

signal save_started
signal save_progress(percentage: float)
signal save_completed(success: bool, error_message: String)

const SAVES_DIR = "user://saves"
var slot_manager
var _is_saving = false
var _is_loading = false


func _ready() -> void:
	var SaveSlotManagerClass = load("res://Scripts/Managers/SaveSlotManager.gd")
	slot_manager = SaveSlotManagerClass.new()
	add_to_group("managers")
	
	# Ensure flags are reset for this fresh instance
	_is_saving = false
	_is_loading = false


## Save current game to a slot
func save_game(slot_id: String) -> void:
	if _is_saving or _is_loading:
		push_error("Save/load already in progress")
		return
	
	_is_saving = true
	save_started.emit()
	
	# Defer the actual save to avoid blocking
	call_deferred("_perform_save", slot_id)


## Load game from a slot
func load_game(slot_id: String) -> void:
	if _is_saving or _is_loading:
		push_error("Save/load already in progress")
		return
	
	_is_loading = true
	save_started.emit()
	
	# Defer the actual load to avoid blocking
	call_deferred("_perform_load", slot_id)


## Create a new game in a slot
func create_new_game(slot_id: String) -> void:
	if _is_saving or _is_loading:
		push_error("Save/load already in progress")
		return
	
	_is_loading = true
	save_started.emit()
	
	# Defer the actual creation to avoid blocking
	call_deferred("_perform_create_new", slot_id)


## Perform the actual save operation
func _perform_save(slot_id: String) -> void:
	var slot_path = SAVES_DIR.path_join(slot_id)
	
	# Create slot if it doesn't exist
	if not DirAccess.dir_exists_absolute(slot_path):
		var created = slot_manager.create_slot(slot_id)
		if not created:
			_finish_save(false, "Failed to create save slot: %s" % slot_id)
			return
	
	var data_manager = load("res://Scripts/Managers/SaveDataManager.gd").new(slot_path)
	
	# Set voxel stream path to target slot FIRST - all data will save to this slot atomically
	var voxel_stream_manager = get_node("/root/VoxelStreamManager")
	if voxel_stream_manager:
		if not voxel_stream_manager.set_database_path_for_slot(slot_id):
			_finish_save(false, "Failed to set voxel stream path for slot: %s" % slot_id)
			return
	
	save_progress.emit(0.25)
	
	# Collect data from managers
	var metadata = data_manager.get_metadata()
	
	# Update player position and rotation if player exists
	var player = get_tree().root.find_child("Player", true, false)
	if player:
		var pos = player.global_position
		metadata["player_position"] = {"x": pos.x, "y": pos.y, "z": pos.z}
		var rot = player.rotation
		metadata["player_rotation"] = {"x": rot.x, "y": rot.y, "z": rot.z}
	
	if not data_manager.set_metadata(metadata):
		_finish_save(false, "Failed to save metadata")
		return
	
	save_progress.emit(0.5)
	
	# Save inventory if manager exists
	var inventory_manager = get_tree().root.find_child("InventoryManager", true, false)
	if inventory_manager and inventory_manager.has_method("get_save_data"):
		var inventory_data = inventory_manager.get_save_data()
		if not data_manager.set_inventory(inventory_data):
			_finish_save(false, "Failed to save inventory")
			return
	
	save_progress.emit(0.75)
	
	# Save hotbar if manager exists
	var tool_manager = get_tree().root.find_child("ToolManager", true, false)
	if tool_manager and tool_manager.has_method("get_save_data"):
		var hotbar_data = tool_manager.get_save_data()
		if not data_manager.set_hotbar(hotbar_data):
			_finish_save(false, "Failed to save hotbar")
			return
	
	save_progress.emit(0.9)
	
	# Save voxels to the same path as other data (atomic save)
	if voxel_stream_manager:
		voxel_stream_manager.save_voxels_async()
		
		# Wait for voxel save to complete
		var save_result = await voxel_stream_manager.save_complete
		if not save_result[0]:  # save_result[0] is success bool
			_finish_save(false, "Voxel save failed: %s" % save_result[1])
			return
	
	save_progress.emit(1.0)
	
	# Update current save slot meta so other systems know which slot is active
	get_tree().root.set_meta("current_save_slot", slot_id)
	CustomLogger.log_info("Set current_save_slot to: %s" % slot_id)
	
	_finish_save(true, "")


## Perform the actual load operation
func _perform_load(slot_id: String) -> void:
	var slot_path = SAVES_DIR.path_join(slot_id)
	
	if not DirAccess.dir_exists_absolute(slot_path):
		_finish_load(false, "Save slot does not exist: %s" % slot_id)
		return
	
	# Validate the slot has required files
	if not slot_manager.validate_slot(slot_id):
		# Log which files are missing
		var required_files = ["metadata.json", "inventory.json", "hotbar.json"]
		for file_name in required_files:
			var file_path = slot_path.path_join(file_name)
			if not FileAccess.file_exists(file_path):
				CustomLogger.log_error("Missing required file: %s" % file_path)
		_finish_load(false, "Save slot is invalid or corrupted: %s" % slot_id)
		return
	
	save_progress.emit(0.25)
	
	# Store slot info for managers to access after reload - MUST do this before reload_current_scene
	get_tree().root.set_meta("current_save_slot", slot_id)
	
	save_progress.emit(0.5)
	
	# Reload the root scene for a clean state
	# MapManager will configure the voxel stream in _ready() using the meta
	get_tree().reload_current_scene()
	
	# Note: After reload_current_scene, this SaveGameManager instance will be destroyed
	# so we cannot emit signals or finish the load here
	_finish_load(true, "")


## Perform the actual new game creation
func _perform_create_new(slot_id: String) -> void:
	# Create the slot
	if not slot_manager.create_slot(slot_id):
		_finish_load(false, "Failed to create save slot: %s" % slot_id)
		return
	
	save_progress.emit(0.3)
	
	# Configure voxel stream to use this slot's database
	if not _setup_voxel_stream(slot_id):
		_finish_load(false, "Failed to configure voxel stream")
		return
	
	save_progress.emit(0.3)
	
	# Store slot info for managers to access after reload
	get_tree().root.set_meta("current_save_slot", slot_id)
	
	# Reload the root scene for a clean state
	var root_scene = get_tree().root.get_child(0)
	if root_scene:
		get_tree().reload_current_scene()
	
	save_progress.emit(1.0)
	_finish_load(true, "")


## Setup voxel stream for a specific save slot
func _setup_voxel_stream(slot_id: String) -> bool:
	var map_manager = get_tree().root.find_child("MapManager", true, false)
	if not map_manager:
		push_error("MapManager not found")
		return false
	
	# Store the slot_id so MapManager can configure the voxel stream in _ready()
	map_manager.set_meta("voxel_db_slot", slot_id)
	
	return true


## Finish save operation
func _finish_save(success: bool, error_message: String) -> void:
	_is_saving = false
	save_completed.emit(success, error_message)
	
	if not success:
		push_error("Save failed: %s" % error_message)


## Finish load operation
func _finish_load(success: bool, error_message: String) -> void:
	_is_loading = false
	save_completed.emit(success, error_message)
	
	if not success:
		push_error("Load failed: %s" % error_message)


## Get list of all save slots
func get_save_slots() -> Array[Dictionary]:
	return slot_manager.get_save_slots()


## Delete a save slot
func delete_slot(slot_id: String) -> bool:
	return slot_manager.delete_slot(slot_id)

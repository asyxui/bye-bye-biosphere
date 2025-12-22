## Simplified SaveGameManager - coordinates save/load operations
## Uses SaveCoordinator for game state, delegates voxel saving
extends Node

class_name SaveGameManager

signal save_started
signal save_progress(percentage: float)
signal save_completed(success: bool, error_message: String)

var slot_manager

func _ready() -> void:
	var SaveSlotManagerClass = load("res://Scripts/Managers/SaveSlotManager.gd")
	slot_manager = SaveSlotManagerClass.new()
	add_to_group("managers")


## Save current game to a slot
func save_game(slot_id: String) -> void:
	# Ensure slot directory exists
	if not SaveDataManager.ensure_slot_directory(slot_id):
		var error = "Failed to create save slot directory: %s" % slot_id
		push_error(error)
		save_completed.emit(false, error)
		return
	
	save_started.emit()
	
	# Update voxel stream database path for this slot (don't reconfigure, just change the path)
	var voxel_stream_manager = get_node_or_null("/root/VoxelStreamManager")
	if voxel_stream_manager and voxel_stream_manager.voxel_stream:
		if not voxel_stream_manager.set_database_path_for_slot(slot_id):
			var error = "Failed to set voxel stream path for slot: %s" % slot_id
			push_error(error)
			save_completed.emit(false, error)
			return
	
	save_progress.emit(0.25)
	
	# Perform save using SaveCoordinator
	var success = SaveCoordinator.save_game(slot_id)
	
	if not success:
		save_completed.emit(false, "SaveCoordinator save failed")
		return
	
	save_progress.emit(0.9)
	
	# Save voxels to the same path as other data
	# Only attempt if voxel stream is in a valid state
	if voxel_stream_manager and voxel_stream_manager.current_state == voxel_stream_manager.State.LOADED:
		voxel_stream_manager.save_voxels_async()
		
		# Wait for voxel save to complete
		var save_result = await voxel_stream_manager.save_complete
		if not save_result[0]:  # save_result[0] is success bool
			var error = "Voxel save failed: %s" % save_result[1]
			push_error(error)
			save_completed.emit(false, error)
			return
	
	save_progress.emit(1.0)
	
	# Update current save slot meta so other systems know which slot is active
	get_tree().root.set_meta("current_save_slot", slot_id)
	CustomLogger.log_info("Saved slot: %s" % slot_id)
	
	save_completed.emit(true, "")


## Load game from a slot
func load_game(slot_id: String) -> void:
	save_started.emit()
	
	# Configure voxel stream for this slot
	var voxel_stream_manager = get_node_or_null("/root/VoxelStreamManager")
	if voxel_stream_manager:
		if not await voxel_stream_manager.configure_stream(slot_id):
			var error = "Failed to configure voxel stream for slot: %s" % slot_id
			push_error(error)
			save_completed.emit(false, error)
			return
	
	save_progress.emit(0.25)
	
	# Wait for terrain to be ready
	var map_manager = get_tree().root.find_child("MapManager", true, false)
	if map_manager and map_manager.has_method("wait_for_terrain_ready"):
		await map_manager.wait_for_terrain_ready()
	
	save_progress.emit(0.5)
	
	# Initialize MapManager voxel systems
	if map_manager and map_manager.has_method("initialize_voxel_systems"):
		await map_manager.initialize_voxel_systems()
	
	save_progress.emit(0.65)
	
	# Wait for terrain to stabilize
	if map_manager and map_manager.has_method("wait_for_terrain_stabilization"):
		await map_manager.wait_for_terrain_stabilization()
	
	save_progress.emit(0.75)
	
	# Load game data using SaveCoordinator
	var save_data = SaveCoordinator.load_game(slot_id)
	
	if save_data == null:
		save_completed.emit(false, "SaveCoordinator load failed")
		return
	
	save_progress.emit(0.85)
	
	# Restore game state from loaded data
	if not SaveCoordinator.restore_game_state(save_data):
		save_completed.emit(false, "Failed to restore game state")
		return
	
	save_progress.emit(1.0)
	
	# Update current save slot meta
	get_tree().root.set_meta("current_save_slot", slot_id)
	CustomLogger.log_info("Loaded slot: %s" % slot_id)
	
	save_completed.emit(true, "")


## Create a new game in a slot
func create_new_game(slot_id: String) -> void:
	# Ensure slot directory exists
	if not SaveDataManager.ensure_slot_directory(slot_id):
		var error = "Failed to create save slot directory: %s" % slot_id
		push_error(error)
		save_completed.emit(false, error)
		return
	
	save_started.emit()
	
	# Configure voxel stream for new slot
	var voxel_stream_manager = get_node_or_null("/root/VoxelStreamManager")
	if voxel_stream_manager:
		if not await voxel_stream_manager.configure_stream(slot_id):
			var error = "Failed to configure voxel stream for new slot: %s" % slot_id
			push_error(error)
			save_completed.emit(false, error)
			return
	
	save_progress.emit(0.5)
	save_progress.emit(1.0)
	
	# Update current save slot meta
	get_tree().root.set_meta("current_save_slot", slot_id)
	CustomLogger.log_info("Created new slot: %s" % slot_id)
	
	save_completed.emit(true, "")


## Get list of all save slots
func get_save_slots() -> Array:
	return slot_manager.get_save_slots()


## Delete a save slot
func delete_slot(slot_id: String) -> bool:
	return slot_manager.delete_slot(slot_id)

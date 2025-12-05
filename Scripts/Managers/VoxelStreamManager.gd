## Manages the lifecycle of voxel stream (loading, saving, resetting)
## Handles all stream configuration and validation
extends Node

signal stream_ready
signal stream_reconfigured  # Emitted after stream is reconfigured (for tool reinit)
signal save_complete(success: bool, error_message: String)
signal reset_complete(success: bool, error_message: String)

enum State {
	IDLE,
	CONFIGURING,
	LOADED,
	SAVING,
	UNLOADING
}

var current_state: State = State.IDLE
var current_slot_id: String = ""
var voxel_terrain: VoxelLodTerrain = null
var voxel_stream: VoxelStreamSQLite = null

const SAVES_DIR = "user://saves"


func _ready() -> void:
	CustomLogger.log_info("VoxelStreamManager initialized")


## Set the database path for a specific save slot without full reconfiguration
## This allows atomic saves where all data (inventory, metadata, voxels) go to same path
func set_database_path_for_slot(slot_id: String) -> bool:
	if not voxel_stream:
		push_error("Cannot set database path: voxel_stream not initialized")
		return false
	
	if not voxel_terrain:
		voxel_terrain = get_tree().root.find_child("Terrain", true, false)
		if not voxel_terrain:
			push_error("Cannot set database path: terrain not found")
			return false
	
	# Build path to voxel database - ensure slot directory exists
	var slot_dir = SAVES_DIR.path_join(slot_id)
	if not DirAccess.dir_exists_absolute(slot_dir):
		if DirAccess.make_dir_recursive_absolute(slot_dir) != OK:
			push_error("Failed to create save slot directory: %s" % slot_dir)
			return false
	
	# Convert user:// path to absolute filesystem path for VoxelStreamSQLite
	var absolute_slot_dir = ProjectSettings.globalize_path(slot_dir)
	var voxel_db_path = absolute_slot_dir.path_join("world.sqlite")
	
	# Change the stream's database path
	# NOTE: VoxelStreamSQLite automatically flushes pending blocks to the old database
	# when database_path is changed, ensuring atomicity
	voxel_stream.database_path = voxel_db_path
	current_slot_id = slot_id
	
	return true


## Configure the voxel stream for a specific save slot
func configure_stream(slot_id: String) -> bool:
	if current_state == State.CONFIGURING or current_state == State.SAVING or current_state == State.UNLOADING:
		CustomLogger.log_warn("Cannot configure stream while in state: %s" % State.keys()[current_state])
		return false
	
	current_state = State.CONFIGURING
	current_slot_id = slot_id
	
	# Find the terrain node
	voxel_terrain = get_tree().root.find_child("Terrain", true, false)
	if not voxel_terrain:
		CustomLogger.log_error("Terrain node not found in scene")
		current_state = State.IDLE
		return false
	
	# IMPORTANT: Clear the existing stream first to stop it from saving to default location
	CustomLogger.log_info("Clearing existing voxel stream")
	voxel_terrain.stream = null
	await get_tree().process_frame  # Give it a frame to process
	
	# Build path to voxel database - ensure slot directory exists
	var slot_dir = SAVES_DIR.path_join(slot_id)
	if not DirAccess.dir_exists_absolute(slot_dir):
		CustomLogger.log_warn("Save slot directory does not exist: %s" % slot_dir)
		# Try to create it
		if DirAccess.make_dir_recursive_absolute(slot_dir) != OK:
			CustomLogger.log_error("Failed to create save slot directory: %s" % slot_dir)
			current_state = State.IDLE
			return false
	
	# Convert user:// path to absolute filesystem path for VoxelStreamSQLite
	var absolute_slot_dir = ProjectSettings.globalize_path(slot_dir)
	var voxel_db_path = absolute_slot_dir.path_join("world.sqlite")
	
	CustomLogger.log_info("Converting slot_dir '%s' to absolute path '%s'" % [slot_dir, absolute_slot_dir])
	CustomLogger.log_info("Voxel database absolute path: %s" % voxel_db_path)
	
	# Create new stream with the correct path
	voxel_stream = VoxelStreamSQLite.new()
	voxel_stream.save_generator_output = true
	voxel_stream.database_path = voxel_db_path
	CustomLogger.log_info("Created new VoxelStreamSQLite with database_path: %s" % voxel_db_path)
	
	# Swap the stream
	voxel_terrain.stream = voxel_stream
	CustomLogger.log_info("Configured voxel stream for slot: %s" % slot_id)
	
	current_state = State.LOADED
	stream_ready.emit()
	stream_reconfigured.emit()  # Signal to reinit tools
	return true


## Save modified voxel blocks asynchronously to current stream
## IMPORTANT: set_database_path_for_slot() must be called first to set target path
func save_voxels_async() -> void:
	if current_state != State.LOADED:
		CustomLogger.log_warn("Cannot save in state: %s" % State.keys()[current_state])
		save_complete.emit(false, "Invalid state for save: %s" % State.keys()[current_state])
		return
	
	# Find terrain fresh (cached reference may be invalid after scene reload)
	voxel_terrain = get_tree().root.find_child("Terrain", true, false)
	if not voxel_terrain:
		CustomLogger.log_error("Cannot save: voxel_terrain not found")
		save_complete.emit(false, "Voxel terrain not found")
		return
	
	current_state = State.SAVING
	CustomLogger.log_info("Initiated voxel save for slot: %s" % current_slot_id)
	
	# Save modified blocks to the currently configured stream
	voxel_terrain.save_modified_blocks()
	
	# Wait for the async save operation to complete in the engine
	# Multiple frames needed for VoxelStreamSQLite to write to disk
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Explicitly flush remaining cached blocks to ensure everything is written
	if voxel_stream:
		voxel_stream.flush()
	
	# Wait one more frame for flush to complete
	await get_tree().process_frame
	
	# Validate the database was written correctly
	if _validate_voxel_database(current_slot_id):
		CustomLogger.log_success("Voxel save validated successfully for slot: %s" % current_slot_id)
		current_state = State.LOADED
		save_complete.emit(true, "")
	else:
		CustomLogger.log_error("Voxel database validation failed after save")
		current_state = State.LOADED
		save_complete.emit(false, "Database validation failed")


## Reset the voxel world (delete and recreate save slot)
func reset_world_async() -> void:
	if current_slot_id.is_empty():
		CustomLogger.log_error("Cannot reset: slot_id invalid")
		reset_complete.emit(false, "Invalid slot_id")
		return
	
	# Find terrain fresh (cached reference may be invalid after scene reload)
	voxel_terrain = get_tree().root.find_child("Terrain", true, false)
	if not voxel_terrain:
		CustomLogger.log_error("Cannot reset: terrain not found")
		reset_complete.emit(false, "Terrain not found")
		return
	
	current_state = State.UNLOADING
	
	# Save any pending modifications before reset
	CustomLogger.log_info("Saving before reset...")
	voxel_terrain.save_modified_blocks()
	
	await get_tree().process_frame
	
	# Unload the current stream
	voxel_terrain.stream = null
	voxel_stream = null
	
	await get_tree().process_frame
	
	# Delete and recreate the save slot
	var SaveSlotManagerClass = load("res://Scripts/Managers/SaveSlotManager.gd")
	var slot_manager = SaveSlotManagerClass.new()
	
	if not slot_manager.delete_slot(current_slot_id):
		CustomLogger.log_error("Failed to delete slot for reset: %s" % current_slot_id)
		reset_complete.emit(false, "Failed to delete slot")
		return
	
	if not slot_manager.create_slot(current_slot_id):
		CustomLogger.log_error("Failed to recreate slot after reset: %s" % current_slot_id)
		reset_complete.emit(false, "Failed to recreate slot")
		return
	
	# Reset state to IDLE before reconfiguring
	current_state = State.IDLE
	
	# Reconfigure stream for the fresh slot
	if await configure_stream(current_slot_id):
		CustomLogger.log_success("World reset complete")
		reset_complete.emit(true, "")
	else:
		CustomLogger.log_error("Failed to configure stream after reset")
		reset_complete.emit(false, "Failed to configure stream")


## Validate that the voxel database is valid and accessible
func _validate_voxel_database(slot_id: String = "") -> bool:
	if not voxel_stream:
		return false
	
	# If no slot_id provided, use the currently configured one
	if slot_id.is_empty():
		slot_id = current_slot_id
	
	if slot_id.is_empty():
		CustomLogger.log_error("Cannot validate: no slot_id")
		return false
	
	var slot_dir = SAVES_DIR.path_join(slot_id)
	var absolute_slot_dir = ProjectSettings.globalize_path(slot_dir)
	var voxel_db_path = absolute_slot_dir.path_join("world.sqlite")
	
	CustomLogger.log_info("Validating voxel database at: %s" % voxel_db_path)
	
	# Check if file exists
	if not FileAccess.file_exists(voxel_db_path):
		# Also check with user:// path in case it was saved there
		var user_path = slot_dir.path_join("world.sqlite")
		if FileAccess.file_exists(user_path):
			CustomLogger.log_warn("Found database at user:// path: %s" % user_path)
			return true
		
		CustomLogger.log_warn("Voxel database file does not exist at: %s" % voxel_db_path)
		return false
	
	# Try to open and close the database to verify it's valid
	var test_file = FileAccess.open(voxel_db_path, FileAccess.READ)
	if test_file == null:
		CustomLogger.log_error("Cannot open voxel database: %s" % voxel_db_path)
		return false
	
	# If we can read it, it's valid
	CustomLogger.log_success("Voxel database is valid: %s" % voxel_db_path)
	return true


## Get current voxel system state
func get_state() -> State:
	return current_state


## Get current save slot ID
func get_current_slot() -> String:
	return current_slot_id

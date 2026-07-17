## Manages the lifecycle of voxel stream (loading, saving, resetting)
## Handles all stream configuration and validation
extends Node

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
var current_slot_id: String = "default"
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
	if current_state != State.IDLE:
		CustomLogger.log_warn("Cannot configure stream while in state: %s" % State.keys()[current_state])
		return false

	current_state = State.CONFIGURING
	current_slot_id = slot_id

	voxel_terrain = get_tree().root.find_child("Terrain", true, false)
	if not voxel_terrain:
		CustomLogger.log_error("Terrain node not found in scene")
		current_state = State.IDLE
		return false

	var slot_dir = SAVES_DIR.path_join(slot_id)
	if not DirAccess.dir_exists_absolute(slot_dir):
		CustomLogger.log_warn("Save slot directory does not exist: %s" % slot_dir)
		# Try to create it
		if DirAccess.make_dir_recursive_absolute(slot_dir) != OK:
			CustomLogger.log_error("Failed to create save slot directory: %s" % slot_dir)
			current_state = State.IDLE
			return false

	var absolute_slot_dir = ProjectSettings.globalize_path(slot_dir)
	var voxel_db_path = absolute_slot_dir.path_join("world.sqlite")

	voxel_stream = VoxelStreamSQLite.new()
	voxel_stream.save_generator_output = false
	voxel_stream.database_path = voxel_db_path
	CustomLogger.log_info("Created new VoxelStreamSQLite with database_path: %s" % voxel_db_path)

	_prepare_generator_performance_capture()
	# Swap the stream only after resetting capture data; generation can now begin.
	voxel_terrain.stream = voxel_stream
	CustomLogger.log_info("Configured voxel stream for slot: %s" % slot_id)

	current_state = State.LOADED
	return true


func unload_stream() -> bool:
	if current_state == State.IDLE:
		return true
	if current_state != State.LOADED:
		CustomLogger.log_warn("Cannot unload stream while in state: %s" % State.keys()[current_state])
		return false

	current_state = State.UNLOADING
	var terrain = voxel_terrain
	if not terrain:
		terrain = get_tree().root.find_child("Terrain", true, false)
	if terrain:
		terrain.stream = null
	voxel_stream = null
	await get_tree().process_frame
	current_state = State.IDLE
	return true


## Save modified voxel blocks asynchronously to current stream
## IMPORTANT: set_database_path_for_slot() must be called first to set target path
func save_voxels_async() -> bool:
	if current_state != State.LOADED:
		CustomLogger.log_warn("Cannot save in state: %s" % State.keys()[current_state])
		save_complete.emit(false, "Invalid state for save: %s" % State.keys()[current_state])
		return false

	# Find terrain fresh (cached reference may be invalid after scene reload)
	voxel_terrain = get_tree().root.find_child("Terrain", true, false)
	if not voxel_terrain:
		CustomLogger.log_error("Cannot save: voxel_terrain not found")
		save_complete.emit(false, "Voxel terrain not found")
		return false

	current_state = State.SAVING
	CustomLogger.log_info("Initiated voxel save for slot: %s" % current_slot_id)

	var tracker = voxel_terrain.save_modified_blocks()
	var total_tasks = tracker.get_total_tasks()
	CustomLogger.log_info("Voxel save tracker: %d tasks" % total_tasks)
	if total_tasks > 0:
		var last_tracker_log = Time.get_ticks_msec()
		while not tracker.is_complete():
			if tracker.is_aborted():
				current_state = State.LOADED
				save_complete.emit(false, "Voxel save was aborted")
				return false
			var now = Time.get_ticks_msec()
			if now - last_tracker_log >= 1000:
				CustomLogger.log_info("Voxel save tracker remaining: %d" % tracker.get_remaining_tasks())
				last_tracker_log = now
			await get_tree().process_frame
		if tracker.is_aborted():
			current_state = State.LOADED
			save_complete.emit(false, "Voxel save was aborted")
			return false

	if total_tasks > 0 and voxel_stream:
		voxel_stream.flush()
	current_state = State.LOADED
	CustomLogger.log_info("Voxel save completed for slot: %s" % current_slot_id)
	save_complete.emit(true, "")
	return true


## Reset the voxel world (delete and recreate save slot)
func reset_world_async() -> void:
	if current_slot_id.is_empty():
		CustomLogger.log_error("Cannot reset: slot_id invalid")
		reset_complete.emit(false, "Invalid slot_id")
		return

	if not await unload_stream():
		reset_complete.emit(false, "Failed to unload stream")
		return

	# Delete and recreate the save slot using SaveManager
	if not SaveManager.delete_slot(current_slot_id):
		CustomLogger.log_error("Failed to delete slot for reset: %s" % current_slot_id)
		reset_complete.emit(false, "Failed to delete slot")
		return

	if not SaveManager.create_slot(current_slot_id):
		CustomLogger.log_error("Failed to recreate slot after reset: %s" % current_slot_id)
		reset_complete.emit(false, "Failed to recreate slot")
		return

	CustomLogger.log_success("World reset complete")
	reset_complete.emit(true, "")


func get_state() -> State:
	return current_state


func get_current_slot() -> String:
	return current_slot_id


func update_generator_performance_for_timer(timer_id: int) -> void:
	if not voxel_terrain:
		return
	var generator: Variant = voxel_terrain.generator
	if not generator or not generator.has_method("get_performance_statistics"):
		return
	var substeps: Array = []
	for statistic in generator.get_performance_statistics():
		substeps.append({
			"label": statistic.label,
			"total": float(statistic.total_usec) / 1000000.0,
			"count": int(statistic.count),
			"max": float(statistic.max_usec) / 1000000.0,
		})
	PerformanceTracker.set_active_substeps(timer_id, substeps)


func _prepare_generator_performance_capture() -> void:
	var generator: Variant = voxel_terrain.generator
	if not generator or not generator.has_method("reset_performance_statistics"):
		return
	generator.reset_performance_statistics()
	generator.set_performance_capture_enabled(PerformanceTracker.is_display_enabled())

extends Node

# Signals
signal save_started
signal save_progress(percentage: float)
signal save_completed(success: bool, error_message: String)
signal restoration_started
signal restoration_completed
signal restoration_failed(error: String)

# Constants
const SAVES_DIR = "user://saves"

# State
var current_slot_id: String = ""

## Get list of all available save slots
func get_save_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	
	# Create saves directory if it doesn't exist
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		var user_dir = DirAccess.open("user://")
		if user_dir:
			user_dir.make_dir("saves")
		return slots
	
	var dir = DirAccess.open(SAVES_DIR)
	if dir == null:
		push_error("Failed to open saves directory: %s" % SAVES_DIR)
		return slots
	
	dir.list_dir_begin()
	var dir_name = dir.get_next()
	
	while dir_name != "":
		if dir_name != "." and dir_name != ".." and not dir_name.begins_with("."):
			var slot_path = SAVES_DIR.path_join(dir_name)
			if DirAccess.dir_exists_absolute(slot_path):
				var metadata = _load_slot_metadata(slot_path)
				slots.append({
					"id": dir_name,
					"path": slot_path,
					"timestamp": metadata.get("timestamp", 0),
					"player_position": metadata.get("player_position", {}),
					"version": metadata.get("version", 1)
				})
		dir_name = dir.get_next()
	
	# Sort by timestamp descending (newest first)
	slots.sort_custom(func(a, b): return a["timestamp"] > b["timestamp"])
	
	return slots


## Get metadata for a specific slot
func get_slot_metadata(slot_id: String) -> Dictionary:
	var slot_path = get_slot_directory(slot_id)
	return _load_slot_metadata(slot_path)


## Create a new save slot
func create_slot(slot_id: String) -> bool:
	var slot_path = SAVES_DIR.path_join(slot_id)
	
	# Check if slot already exists
	if DirAccess.dir_exists_absolute(slot_path):
		push_error("Save slot already exists: %s" % slot_id)
		return false
	
	# Create parent saves directory if it doesn't exist
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		if DirAccess.make_dir_recursive_absolute(SAVES_DIR) != OK:
			push_error("Failed to create saves directory: %s" % SAVES_DIR)
			return false
	
	# Create slot directory
	var parent_dir = DirAccess.open(SAVES_DIR)
	if parent_dir == null:
		push_error("Failed to open saves directory: %s" % SAVES_DIR)
		return false
	
	if parent_dir.make_dir(slot_id) != OK:
		push_error("Failed to create save slot directory: %s" % slot_path)
		return false
	
	return true


## Delete a save slot
func delete_slot(slot_id: String) -> bool:
	var slot_path = SAVES_DIR.path_join(slot_id)
	
	if not DirAccess.dir_exists_absolute(slot_path):
		push_error("Save slot does not exist: %s" % slot_id)
		return false
	
	# Recursively delete all files and subdirectories
	if not _delete_directory_recursive(slot_path):
		push_error("Failed to delete slot directory: %s" % slot_path)
		return false
	
	return true


## Get save slot directory path
func get_slot_directory(slot_id: String) -> String:
	return SAVES_DIR.path_join(slot_id)


## Ensure save slot directory exists
func ensure_slot_directory(slot_id: String) -> bool:
	var slot_dir = get_slot_directory(slot_id)
	if not DirAccess.dir_exists_absolute(slot_dir):
		if DirAccess.make_dir_recursive_absolute(slot_dir) != OK:
			push_error("Failed to create slot directory: %s" % slot_dir)
			return false
	return true

## Save game to slot
func save_game(slot_id: String) -> void:
	current_slot_id = slot_id
	save_started.emit()
	
	# Ensure slot directory exists
	if not ensure_slot_directory(slot_id):
		var error = "Failed to create save slot directory: %s" % slot_id
		push_error(error)
		save_completed.emit(false, error)
		return
	
	save_progress.emit(0.1)
	
	# Update voxel stream database path for this slot
	var voxel_stream_manager = get_node_or_null("/root/VoxelStreamManager")
	if voxel_stream_manager and voxel_stream_manager.voxel_stream:
		if not voxel_stream_manager.set_database_path_for_slot(slot_id):
			var error = "Failed to set voxel stream path for slot: %s" % slot_id
			push_error(error)
			save_completed.emit(false, error)
			return
	
	save_progress.emit(0.2)
	
	# Collect data from all saveable components
	var save_data = {}
	var saveable_nodes = get_tree().get_nodes_in_group("saveable")
	
	CustomLogger.log_info("SaveManager: Found %d saveable nodes" % saveable_nodes.size())
	
	var progress_base = 0.2
	var progress_range = 0.5  # 0.2 to 0.7
	
	for i in range(saveable_nodes.size()):
		var node = saveable_nodes[i]
		# Use duck typing - check if node has the required methods
		if node.has_method("get_save_key") and node.has_method("get_save_data"):
			var key = node.get_save_key()
			var data = node.get_save_data()
			save_data[key] = data
			CustomLogger.log_info("Saved data for: %s" % key)
			
		if saveable_nodes.size() > 0:
			var progress = progress_base + (progress_range * (float(i + 1) / float(saveable_nodes.size())))
			save_progress.emit(progress)
	
	# Save to JSON file
	var slot_dir = get_slot_directory(slot_id)
	var data_file = slot_dir.path_join("game_data.json")
	var json_string = JSON.stringify(save_data, "\t")
	
	var file = FileAccess.open(data_file, FileAccess.WRITE)
	if file == null:
		var error = "Failed to write save file: %s" % data_file
		push_error(error)
		save_completed.emit(false, error)
		return
	
	file.store_string(json_string)
	file = null  # Close file
	
	save_progress.emit(0.8)
	
	# Save voxels to the same path as other data
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
	
	# Update current save slot meta
	get_tree().root.set_meta("current_save_slot", slot_id)
	CustomLogger.log_info("SaveManager: Saved slot: %s" % slot_id)
	
	save_completed.emit(true, "")


## Load game data from slot (returns the data dictionary)
func load_game_data(slot_id: String) -> Variant:
	current_slot_id = slot_id
	restoration_started.emit()
	
	var slot_dir = get_slot_directory(slot_id)
	var data_file = slot_dir.path_join("game_data.json")
	
	if not FileAccess.file_exists(data_file):
		var error = "Save file not found: %s" % data_file
		push_error(error)
		restoration_failed.emit(error)
		return null
	
	var file = FileAccess.open(data_file, FileAccess.READ)
	if file == null:
		var error = "Failed to read save file: %s" % data_file
		push_error(error)
		restoration_failed.emit(error)
		return null
	
	var json_string = file.get_as_text()
	var save_data = JSON.parse_string(json_string)
	
	if save_data == null:
		var error = "Failed to parse save file: %s" % data_file
		push_error(error)
		restoration_failed.emit(error)
		return null
	
	return save_data


## Restore all components from save data
## Should be called after voxel stream and world generation are ready
func restore_game_state(save_data: Dictionary) -> bool:
	var saveable_nodes = get_tree().get_nodes_in_group("saveable")
	
	for node in saveable_nodes:
		# Use duck typing - check if node has the required methods
		if node.has_method("get_save_key") and node.has_method("load_save_data"):
			var key = node.get_save_key()
			if key in save_data:
				node.load_save_data(save_data[key])
				CustomLogger.log_info("Restored data for: %s" % key)
	
	restoration_completed.emit()
	return true


## Clear all saveable components (during world transitions)
func clear_all_saveables() -> void:
	var saveable_nodes = get_tree().get_nodes_in_group("saveable")
	
	for node in saveable_nodes:
		# Use duck typing - check if node has the required method
		if node.has_method("clear_save_data"):
			node.clear_save_data()
			CustomLogger.log_info("Cleared data for: %s" % node.get_save_key() if node.has_method("get_save_key") else "unknown")

## Load metadata from a slot directory
func _load_slot_metadata(slot_path: String) -> Dictionary:
	var data_file = slot_path.path_join("game_data.json")
	
	if not FileAccess.file_exists(data_file):
		return {}
	
	var file = FileAccess.open(data_file, FileAccess.READ)
	if file == null:
		return {}
	
	var json_string = file.get_as_text()
	var data = JSON.parse_string(json_string)
	
	if not data is Dictionary:
		return {}
	
	# Extract metadata from the full game data
	# Look for common metadata keys that saveables might provide
	var metadata = {}
	
	# Check for player data
	if "player" in data:
		var player_data = data["player"]
		if player_data is Dictionary and "position" in player_data:
			metadata["player_position"] = player_data["position"]
	
	# Check for game metadata
	if "game_metadata" in data:
		var game_meta = data["game_metadata"]
		if game_meta is Dictionary:
			metadata["timestamp"] = game_meta.get("timestamp", 0)
			metadata["version"] = game_meta.get("version", 1)
	
	# If no explicit timestamp, try to get file modification time
	if not "timestamp" in metadata:
		metadata["timestamp"] = FileAccess.get_modified_time(data_file) * 1000
	
	# Default version
	if not "version" in metadata:
		metadata["version"] = 1
	
	return metadata


## Recursively delete a directory and all its contents
func _delete_directory_recursive(path: String) -> bool:
	var dir = DirAccess.open(path)
	if dir == null:
		push_error("Failed to open directory: %s" % path)
		return false
	
	dir.list_dir_begin()
	var entry = dir.get_next()
	
	while entry != "":
		if entry != "." and entry != "..":
			var full_path = path.path_join(entry)
			
			if DirAccess.dir_exists_absolute(full_path):
				# Recursively delete subdirectories
				if not _delete_directory_recursive(full_path):
					return false
			else:
				# Delete files
				if dir.remove(entry) != OK:
					push_error("Failed to delete file: %s" % full_path)
					return false
		
		entry = dir.get_next()
	
	# After all contents are deleted, delete the directory itself
	var parent_path = path.get_base_dir()
	var dir_name = path.get_file()
	var parent_dir = DirAccess.open(parent_path)
	
	if parent_dir == null:
		push_error("Failed to open parent directory: %s" % parent_path)
		return false
	
	if parent_dir.remove(dir_name) != OK:
		push_error("Failed to remove directory: %s" % path)
		return false
	
	return true

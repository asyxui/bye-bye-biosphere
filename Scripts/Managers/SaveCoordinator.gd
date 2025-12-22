## SaveCoordinator - Orchestrates save/load operations
## Collects save data from all components in "saveable" group
## Manages game_data.json persistence
extends Node

signal save_started
signal save_progress(percentage: float)
signal save_failed(error: String)
signal save_completed
signal restoration_started
signal restoration_failed(error: String)
signal restoration_completed

var current_slot_id: String


func _ready() -> void:
	# Initialize if needed
	pass


## Save game to slot
## Returns true if successful, false otherwise
func save_game(slot_id: String) -> bool:
	current_slot_id = slot_id
	save_started.emit()
	
	var save_data = {}
	var saveable_nodes = get_tree().get_nodes_in_group("saveable")
	
	CustomLogger.log_info("SaveCoordinator: Found %d saveable nodes" % saveable_nodes.size())
	
	# Collect data from all saveable components
	for node in saveable_nodes:
		# Use duck typing - check if node has the required methods
		if node.has_method("get_save_key") and node.has_method("get_save_data"):
			var key = node.get_save_key()
			var data = node.get_save_data()
			save_data[key] = data
			CustomLogger.log_info("Saved data for: %s" % key)
			if saveable_nodes.size() > 0:
				save_progress.emit(float(saveable_nodes.find(node) + 1) / float(saveable_nodes.size()))
	
	# Save to JSON file
	var slot_dir = _get_slot_directory(slot_id)
	if not _ensure_slot_directory(slot_dir):
		var error = "Failed to create save slot directory: %s" % slot_dir
		push_error(error)
		save_failed.emit(error)
		return false
	
	var data_file = slot_dir.path_join("game_data.json")
	var json_string = JSON.stringify(save_data, "\t")
	
	var file = FileAccess.open(data_file, FileAccess.WRITE)
	if file == null:
		var error = "Failed to write save file: %s" % data_file
		push_error(error)
		save_failed.emit(error)
		return false
	
	file.store_string(json_string)
		
	save_progress.emit(1.0)
	save_completed.emit()
	return true


## Load game from slot
## Returns loaded data dictionary if successful, null otherwise
func load_game(slot_id: String) -> Variant:
	current_slot_id = slot_id
	restoration_started.emit()
	
	var slot_dir = _get_slot_directory(slot_id)
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


## Get save slot directory
func _get_slot_directory(slot_id: String) -> String:
	return "user://saves/%s" % slot_id


## Ensure save slot directory exists
func _ensure_slot_directory(slot_dir: String) -> bool:
	if not DirAccess.dir_exists_absolute(slot_dir):
		var parent_dir = DirAccess.open(slot_dir.get_base_dir())
		if parent_dir:
			var error = parent_dir.make_dir(slot_dir.get_file())
			if error != OK:
				return false
	return true

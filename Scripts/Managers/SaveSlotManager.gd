## Manages save slots and their metadata
## Handles listing, creating, deleting, and validating save slots
class_name SaveSlotManager

const SAVES_DIR = "user://saves"


## Get list of all available save slots
func get_save_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	
	# Create saves directory if it doesn't exist
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		var user_dir = DirAccess.open("user://")
		if user_dir:
			user_dir.make_dir("ByeByeBiosphere/saves")
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
	var slot_path = SAVES_DIR.path_join(slot_id)
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
	
	# Initialize slot with default data files
	var SaveDataManagerClass = load("res://Scripts/Managers/SaveDataManager.gd")
	var data_manager = SaveDataManagerClass.new(slot_path)
	if not data_manager.init_schema():
		push_error("Failed to initialize save slot: %s" % slot_id)
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


## Check if a slot is valid (has all required files)
func validate_slot(slot_id: String) -> bool:
	var slot_path = SAVES_DIR.path_join(slot_id)
	
	if not DirAccess.dir_exists_absolute(slot_path):
		return false
	
	# Check for required files
	var required_files = ["metadata.json", "inventory.json", "hotbar.json"]
	
	for file_name in required_files:
		var file_path = slot_path.path_join(file_name)
		if not FileAccess.file_exists(file_path):
			return false
	
	return true


## Load metadata from a slot directory
func _load_slot_metadata(slot_path: String) -> Dictionary:
	var metadata_path = slot_path.path_join("metadata.json")
	
	if not FileAccess.file_exists(metadata_path):
		return {}
	
	var file = FileAccess.open(metadata_path, FileAccess.READ)
	if file == null:
		return {}
	
	var json_string = file.get_as_text()
	var data = JSON.parse_string(json_string)
	
	return data if data is Dictionary else {}

## Decoupled save data wrapper for direct file access
## Any system can instantiate this to read/write save data without tight coupling to SaveGameManager
## Folder structure:
##   savegame_name/
##   ├── world.sqlite (voxel terrain data)
##   ├── metadata.json (version, timestamp, player position/rotation)
##   ├── inventory.json (inventory slots and items)
##   └── hotbar.json (hotbar configuration)
class_name SaveDataManager

var slot_dir: String
var voxel_db_path: String
var metadata_path: String
var inventory_path: String
var hotbar_path: String


func _init(slot_directory: String) -> void:
	slot_dir = slot_directory
	voxel_db_path = slot_directory.path_join("world.sqlite")
	metadata_path = slot_directory.path_join("metadata.json")
	inventory_path = slot_directory.path_join("inventory.json")
	hotbar_path = slot_directory.path_join("hotbar.json")
	
	# Ensure directory exists
	if not DirAccess.dir_exists_absolute(slot_dir):
		var parent_dir = DirAccess.open(slot_dir.get_base_dir())
		if parent_dir:
			parent_dir.make_dir(slot_dir.get_file())


## Load JSON file from the given path
func _load_json(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		return null
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Failed to read file: %s" % file_path)
		return null
	
	var json_string = file.get_as_text()
	var data = JSON.parse_string(json_string)
	
	if data == null:
		push_error("Failed to parse JSON from: %s" % file_path)
		return null
	
	return data


## Save JSON file to the given path
func _save_json(file_path: String, data: Variant) -> bool:
	var json_string = JSON.stringify(data, "\t")
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open file for writing: %s" % file_path)
		return false
	
	file.store_string(json_string)
	return true


## Get metadata
func get_metadata() -> Dictionary:
	var data = _load_json(metadata_path)
	if data == null:
		return _create_default_metadata()
	return data


## Set metadata
func set_metadata(data: Dictionary) -> bool:
	# Update timestamp
	data["timestamp"] = Time.get_ticks_msec()
	return _save_json(metadata_path, data)


## Get inventory data
func get_inventory() -> Array:
	var data = _load_json(inventory_path)
	if data == null:
		return []
	return data if data is Array else []


## Set inventory data
func set_inventory(inventory_data: Array) -> bool:
	return _save_json(inventory_path, inventory_data)


## Get hotbar data
func get_hotbar() -> Array:
	var data = _load_json(hotbar_path)
	if data == null:
		return []
	return data if data is Array else []


## Set hotbar data
func set_hotbar(hotbar_data: Array) -> bool:
	return _save_json(hotbar_path, hotbar_data)


## Get the voxel database path
func get_voxel_db_path() -> String:
	return voxel_db_path


## Initialize slot with default data files
func init_schema() -> bool:
	var success = true
	success = success and set_metadata(_create_default_metadata())
	success = success and set_inventory([])
	success = success and set_hotbar([])
	return success


## Create default metadata structure
func _create_default_metadata() -> Dictionary:
	return {
		"version": 1,
		"timestamp": 0,
		"player_position": {"x": 26.0, "y": 59.0, "z": 35.0},
		"player_rotation": {"x": 0.0, "y": 0.0, "z": 0.0}
	}

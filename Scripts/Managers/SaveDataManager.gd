## Simplified save data manager - handles slot directory management
## Game data JSON I/O is now handled by SaveCoordinator
class_name SaveDataManager
extends Node


## Get save slot directory
static func get_slot_directory(slot_id: String) -> String:
	return "user://saves/%s" % slot_id


## Get voxel database path for slot
static func get_voxel_db_path(slot_id: String) -> String:
	return get_slot_directory(slot_id).path_join("world.sqlite")


## Ensure save slot directory exists
static func ensure_slot_directory(slot_id: String) -> bool:
	var slot_dir = get_slot_directory(slot_id)
	if not DirAccess.dir_exists_absolute(slot_dir):
		var parent_dir = DirAccess.open(slot_dir.get_base_dir())
		if parent_dir:
			var error = parent_dir.make_dir(slot_dir.get_file())
			if error != OK:
				return false
	return true

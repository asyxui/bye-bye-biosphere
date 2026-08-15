extends Node

signal save_started
signal save_progress(percentage: float)
signal save_completed(success: bool, error_message: String)
signal restoration_started
signal restoration_completed
signal restoration_failed(error: String)

const SAVES_DIR = "user://saves"

# Saveable nodes are discovered by group membership, but their restore order
# is part of the persistence contract. Machines must exist before conveyor
# ports can be reconnected, and machine buffers must exist before belt items
# resume simulation.
const SAVE_ORDER: Array[String] = ["machines", "conveyors", "biosphere", "inventory", "player", "tools"]
const CLEAR_ORDER: Array[String] = ["conveyors", "machines", "biosphere", "inventory", "player", "tools"]

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


func get_slot_metadata(slot_id: String) -> Dictionary:
	var slot_path = get_slot_directory(slot_id)
	return _load_slot_metadata(slot_path)


func create_slot(slot_id: String) -> bool:
	var slot_path = SAVES_DIR.path_join(slot_id)

	if DirAccess.dir_exists_absolute(slot_path):
		push_error("Save slot already exists: %s" % slot_id)
		return false

	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		if DirAccess.make_dir_recursive_absolute(SAVES_DIR) != OK:
			push_error("Failed to create saves directory: %s" % SAVES_DIR)
			return false

	var parent_dir = DirAccess.open(SAVES_DIR)
	if parent_dir == null:
		push_error("Failed to open saves directory: %s" % SAVES_DIR)
		return false

	if parent_dir.make_dir(slot_id) != OK:
		push_error("Failed to create save slot directory: %s" % slot_path)
		return false

	if not _write_json_atomic(slot_path, {}):
		push_error("Failed to initialize save data: %s" % slot_path)
		_delete_directory_recursive(slot_path)
		return false

	return true


func delete_slot(slot_id: String) -> bool:
	var slot_path = SAVES_DIR.path_join(slot_id)

	if not DirAccess.dir_exists_absolute(slot_path):
		push_error("Save slot does not exist: %s" % slot_id)
		return false

	if not _delete_directory_recursive(slot_path):
		push_error("Failed to delete slot directory: %s" % slot_path)
		return false

	return true


func get_slot_directory(slot_id: String) -> String:
	return SAVES_DIR.path_join(slot_id)


func ensure_slot_directory(slot_id: String) -> bool:
	var slot_dir = get_slot_directory(slot_id)
	if not DirAccess.dir_exists_absolute(slot_dir):
		if DirAccess.make_dir_recursive_absolute(slot_dir) != OK:
			push_error("Failed to create slot directory: %s" % slot_dir)
			return false
	return true

func save_game(slot_id: String) -> bool:
	current_slot_id = slot_id
	save_started.emit()

	if not ensure_slot_directory(slot_id):
		var error = "Failed to create save slot directory: %s" % slot_id
		push_error(error)
		save_completed.emit(false, error)
		return false

	save_progress.emit(0.1)

	var voxel_stream_manager = get_node_or_null("/root/VoxelStreamManager")
	if voxel_stream_manager and voxel_stream_manager.voxel_stream and voxel_stream_manager.current_slot_id != slot_id:
		if not voxel_stream_manager.set_database_path_for_slot(slot_id):
			var error = "Failed to set voxel stream path for slot: %s" % slot_id
			push_error(error)
			save_completed.emit(false, error)
			return false

	save_progress.emit(0.2)

	var save_data: Dictionary = {}
	var saveable_nodes: Array[Node] = _get_ordered_saveables(SAVE_ORDER)

	CustomLogger.log_info("SaveManager: Found %d saveable nodes" % saveable_nodes.size())

	var progress_base = 0.2
	var progress_range = 0.5 # 0.2 to 0.7

	for i in range(saveable_nodes.size()):
		var node = saveable_nodes[i]
		var key = node.get_save_key()
		var data = node.get_save_data()
		save_data[key] = data
		CustomLogger.log_info("Saved data for: %s" % key)

		if saveable_nodes.size() > 0:
			var progress = progress_base + (progress_range * (float(i + 1) / float(saveable_nodes.size())))
			save_progress.emit(progress)

	var slot_dir = get_slot_directory(slot_id)
	if not _write_json_atomic(slot_dir, save_data):
		var error = "Failed to write save file: %s" % slot_dir.path_join("game_data.json")
		push_error(error)
		save_completed.emit(false, error)
		return false

	save_progress.emit(0.8)

	# Save voxels to the same path as other data
	if voxel_stream_manager and voxel_stream_manager.current_state == voxel_stream_manager.State.LOADED:
		if not await voxel_stream_manager.save_voxels_async():
			var error = "Voxel save failed for slot: %s" % slot_id
			push_error(error)
			save_completed.emit(false, error)
			return false

	save_progress.emit(1.0)

	get_tree().root.set_meta("current_save_slot", slot_id)
	CustomLogger.log_info("SaveManager: Saved slot: %s" % slot_id)

	save_completed.emit(true, "")
	return true


func load_game_data(slot_id: String) -> Variant:
	current_slot_id = slot_id
	restoration_started.emit()

	var slot_dir = get_slot_directory(slot_id)
	var paths = [
		slot_dir.path_join("game_data.json"),
		slot_dir.path_join("game_data.json.tmp"),
		slot_dir.path_join("game_data.json.bak")
	]
	var canonical = paths[0]
	var canonical_data = _read_json_dictionary(canonical)
	if canonical_data is Dictionary:
		return canonical_data

	# Recovery from backup file (corruption)
	for path in paths.slice(1):
		var recovered_data = _read_json_dictionary(path)
		if recovered_data is Dictionary:
			if FileAccess.file_exists(canonical):
				_preserve_corrupt_file(canonical)
			if not _write_json_atomic(slot_dir, recovered_data):
				var recovery_error = "Failed to repair save JSON: %s" % slot_dir
				push_error(recovery_error)
				restoration_failed.emit(recovery_error)
				return null
			return recovered_data

	if FileAccess.file_exists(canonical):
		_preserve_corrupt_file(canonical)
	var empty_data: Dictionary = {}
	if not _write_json_atomic(slot_dir, empty_data):
		var error = "No valid save JSON and failed to repair: %s" % slot_dir
		push_error(error)
		restoration_failed.emit(error)
		return null
	return empty_data


func restore_game_state(save_data: Dictionary) -> bool:
	var saveables_by_key: Dictionary = _get_saveables_by_key()
	var restored_keys: Dictionary = {}

	# Phase 1: instantiate machines, then create conveyor geometry and rebuild
	# machine-port connections against those stable IDs.
	_restore_saveable_key(saveables_by_key, save_data, "machines")
	restored_keys["machines"] = true
	_restore_saveable_key(saveables_by_key, save_data, "conveyors")
	restored_keys["conveyors"] = true

	# Phase 2: restore machine buffers and processing, then release conveyor
	# contents so the first simulation tick sees a complete factory graph.
	var machine_manager: Node = saveables_by_key.get("machines") as Node
	if machine_manager != null and machine_manager.has_method("restore_machine_states"):
		machine_manager.restore_machine_states()
	var conveyor_manager: Node = saveables_by_key.get("conveyors") as Node
	if conveyor_manager != null and conveyor_manager.has_method("restore_saved_contents"):
		conveyor_manager.restore_saved_contents()

	# Phase 3: restore ecological state, inventory, player transform, and tools/UI.
	for key in ["biosphere", "inventory", "player", "tools"]:
		_restore_saveable_key(saveables_by_key, save_data, key)
		restored_keys[key] = true

	# Preserve forward compatibility for saveable systems added later.
	for node in _get_ordered_saveables(SAVE_ORDER):
		var key: String = str(node.get_save_key())
		if restored_keys.has(key):
			continue
		_restore_saveable_key(saveables_by_key, save_data, key)

	restoration_completed.emit()
	return true


func clear_all_saveables() -> void:
	var saveable_nodes: Array[Node] = _get_ordered_saveables(CLEAR_ORDER)

	for node in saveable_nodes:
		node.clear_save_data()
		CustomLogger.log_info("Cleared data for: %s" % node.get_save_key() if node.has_method("get_save_key") else "unknown")


func _get_ordered_saveables(preferred_order: Array[String]) -> Array[Node]:
	var by_key: Dictionary = _get_saveables_by_key()
	var ordered: Array[Node] = []
	for key in preferred_order:
		var ordered_node: Node = by_key.get(key) as Node
		if ordered_node != null:
			ordered.append(ordered_node)
			by_key.erase(key)

	# Preserve forward compatibility for new saveables that have not yet been
	# added to the explicit lifecycle order.
	for remaining_node_value in by_key.values():
		var remaining_node: Node = remaining_node_value as Node
		if remaining_node != null:
			ordered.append(remaining_node)
	return ordered


func _get_saveables_by_key() -> Dictionary:
	var by_key: Dictionary = {}
	for node_value in get_tree().get_nodes_in_group("saveable"):
		var node: Node = node_value as Node
		if node != null and node.has_method("get_save_key"):
			by_key[str(node.get_save_key())] = node
	return by_key


func _restore_saveable_key(saveables_by_key: Dictionary, save_data: Dictionary, key: String) -> void:
	var node: Node = saveables_by_key.get(key) as Node
	if node == null or not save_data.has(key):
		return
	node.load_save_data(save_data[key])
	CustomLogger.log_info("Restored data for: %s" % key)


func _load_slot_metadata(slot_path: String) -> Dictionary:
	var data_file = slot_path.path_join("game_data.json")

	if not FileAccess.file_exists(data_file):
		return {}

	var file = FileAccess.open(data_file, FileAccess.READ)
	if file == null:
		return {}

	var json_string = file.get_as_text()
	file.close()
	var data = JSON.parse_string(json_string)

	if not data is Dictionary:
		return {}

	var metadata = {}

	if "player" in data:
		var player_data = data["player"]
		if player_data is Dictionary and "position" in player_data:
			metadata["player_position"] = player_data["position"]

	if "game_metadata" in data:
		var game_meta = data["game_metadata"]
		if game_meta is Dictionary:
			metadata["timestamp"] = game_meta.get("timestamp", 0)
			metadata["version"] = game_meta.get("version", 1)

	# If no explicit timestamp, try to get file modification time
	if not "timestamp" in metadata:
		metadata["timestamp"] = FileAccess.get_modified_time(data_file) * 1000

	if not "version" in metadata:
		metadata["version"] = 1

	return metadata


func _read_json_dictionary(path: String) -> Variant:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return parsed


func _write_json_atomic(slot_dir: String, save_data: Dictionary) -> bool:
	if not DirAccess.dir_exists_absolute(slot_dir) and DirAccess.make_dir_recursive_absolute(slot_dir) != OK:
		return false
	var canonical = slot_dir.path_join("game_data.json")
	var temporary = slot_dir.path_join("game_data.json.tmp")
	var backup = slot_dir.path_join("game_data.json.bak")
	var file = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	var dir = DirAccess.open(slot_dir)
	if dir == null:
		return false
	var had_canonical = FileAccess.file_exists(canonical)
	if had_canonical:
		if FileAccess.file_exists(backup) and dir.remove("game_data.json.bak") != OK:
			return false
		if dir.rename("game_data.json", "game_data.json.bak") != OK:
			return false
	if dir.rename("game_data.json.tmp", "game_data.json") != OK:
		if had_canonical and FileAccess.file_exists(backup):
			dir.rename("game_data.json.bak", "game_data.json")
		return false
	return true


func _preserve_corrupt_file(path: String) -> bool:
	var dir = DirAccess.open(path.get_base_dir())
	if dir == null:
		return false
	var stamp = str(int(Time.get_unix_time_from_system()))
	var corrupt_name = path.get_file() + "." + stamp + ".corrupt"
	var suffix = 0
	while FileAccess.file_exists(path.get_base_dir().path_join(corrupt_name)):
		suffix += 1
		corrupt_name = path.get_file() + "." + stamp + "-" + str(suffix) + ".corrupt"
	return dir.rename(path.get_file(), corrupt_name) == OK


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

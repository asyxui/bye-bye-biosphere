## Saveable interface for objects that need to persist state
## Implement this interface and add node to "saveable" group to participate in save/load system
class_name Saveable
extends Node

## Return a unique key for this saveable component (e.g., "inventory", "tools", "conveyor")
func get_save_key() -> String:
	push_error("get_save_key not implemented in %s" % name)
	return ""


## Return a dictionary of data to be saved
func get_save_data() -> Dictionary:
	push_error("get_save_data not implemented in %s" % name)
	return {}


## Restore state from saved data
func load_save_data(_data: Dictionary) -> void:
	push_error("load_save_data not implemented in %s" % name)

## Clear/reset state (called during world transitions)
func clear_save_data() -> void:
	push_error("clear_save_data not implemented in %s" % name)
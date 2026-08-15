class_name Saveable
extends Node

func get_save_key() -> String:
	push_error("get_save_key not implemented in %s" % name)
	return ""


func get_save_data() -> Dictionary:
	push_error("get_save_data not implemented in %s" % name)
	return {}


func load_save_data(_data: Dictionary) -> void:
	push_error("load_save_data not implemented in %s" % name)


func clear_save_data() -> void:
	push_error("clear_save_data not implemented in %s" % name)

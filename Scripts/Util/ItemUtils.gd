## ItemUtils.gd
extends Node

func item_object_by_type_id(id: int):
	return load("res://Resources/Items/%s.tres" % item_name_by_type_id(id))

	
func item_name_by_type_id(id: int):
	match id:
		1:
			return "Apple"
		2:
			return "Ore"

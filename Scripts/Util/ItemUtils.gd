## ItemUtils.gd
extends Node

## Resolve item resources by their stable identifier. Resource filenames and
## display names are only an asset lookup detail.
func item_object_by_id(item_id: String) -> InventoryItem:
	for resource_name in ["Apple", "Ore", "IronIngot"]:
		var item = load("res://Resources/Items/%s.tres" % resource_name)
		if item != null and str(item.id) == item_id:
			return item
	return null

func item_object_by_type_id(id: int):
	return item_object_by_id(str(id))


func item_name_by_type_id(id: int):
	match id:
		0:
			return "Rock"
		1:
			return "Apple"
		2:
			return "Ore"
		3:
			return "Dirt"
		4:
			return "Iron Ore"
		5:
			return "Iron Ingot"
		6:
			return "Copper Ore"
		7:
			return "Copper Ingot"

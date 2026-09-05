extends InventoryItem
class_name PlaceableItem

@export var structure_type: String = ""
@export_enum("machine", "conveyor") var placement_category: String = "machine"
@export var placement_icon: Texture2D
@export var placement_description: String = ""

func get_placement_icon() -> Texture2D:
	return placement_icon if placement_icon != null else icon

func get_placement_description() -> String:
	return placement_description if not placement_description.is_empty() else description

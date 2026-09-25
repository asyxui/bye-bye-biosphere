extends Resource
class_name VoxelMaterialDefinition

@export var voxel_type: int = 0
@export var material_name: String = ""
@export var mined_item_id: String = ""

func get_mined_item() -> InventoryItem:
	if mined_item_id.is_empty():
		return null
	return ItemUtils.item_object_by_id(mined_item_id)

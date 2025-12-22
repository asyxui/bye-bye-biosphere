## ItemTool.gd
## Single-step tool for using items

extends "res://Scripts/Tools/BaseTool.gd"
class_name ItemTool

func on_execute(_p: Node) -> void:
	var tool_resource_id = int(self._tool_resource.id)

	if InventoryManager.inventory.remove_item(ItemUtils.item_object_by_type_id(tool_resource_id), 1) > 0:
		var spawnPosition = player.global_position * 4 + player.get_direction() * 7
		spawnPosition.y += 1.2

		MapManager.drop_item(int(self._tool_resource.id), spawnPosition)

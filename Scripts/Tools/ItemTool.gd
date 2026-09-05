## ItemTool.gd
## Single-step tool for using items

extends "res://Scripts/Tools/BaseTool.gd"
class_name ItemTool

func on_execute(_p: Node) -> void:
	var item_id := ToolManager.get_item_binding_id(_tool_resource)
	if item_id.is_empty():
		UIManager.set_placement_status("Item tool needs an inventory item. Use Collect/Destruct from the tool wheel.", false)
		return
	var item: InventoryItem = ItemUtils.item_object_by_id(item_id)
	if item == null:
		UIManager.set_placement_status("Selected item is unavailable", false)
		return

	if InventoryManager.inventory.remove_item(item, 1) > 0:
		var spawnPosition = player.global_position * 4 + player.get_direction() * 7
		spawnPosition.y += 1.2
		MapManager.drop_item(item_id, spawnPosition)
	else:
		UIManager.set_placement_status("No %s available" % item.name, false)

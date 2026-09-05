## Headless smoke tests for item-backed placement bindings.
extends "res://Tests/TestCase.gd"

const CONVEYOR := preload("res://Resources/Items/Conveyor.tres")

func _run() -> void:
	GameStateManager.set_creative_mode(false)
	ToolManager.clear_save_data()
	InventoryManager.clear_save_data()

	check(CONVEYOR is PlaceableItem)
	check((CONVEYOR as PlaceableItem).structure_type == "conveyor")
	var receipt := PlacementReceipt.create(CONVEYOR.id, 1, true, false)
	check(PlacementReceipt.is_valid(receipt))
	check(receipt.get("placement_item_id", "") == CONVEYOR.id)
	check(bool(receipt.get("placement_consumed", false)))
	check(not bool(receipt.get("placement_was_creative", true)))
	var saved_belt := ConveyorBeltObject.new(Vector3.ZERO, Vector3(4, 0, 0), "receipt_belt")
	saved_belt.placement_receipt = receipt
	var restored_belt := ConveyorBeltObject.from_dict(saved_belt.to_dict())
	check(restored_belt.placement_receipt == receipt)
	check(InventoryManager.add_item(CONVEYOR, 2) == 0)
	check(ToolManager.equip_item(0, 0))

	var equipped := ToolManager.get_tool_in_slot(0) as ItemPlacementToolResource
	check(equipped != null)
	check(equipped.item_id == CONVEYOR.id)
	check(equipped.kind == HotbarBinding.KIND_ITEM)
	check(equipped.binding_id == CONVEYOR.id)
	check(equipped.id == "item:%s" % CONVEYOR.id)
	var structured_save := ToolManager.get_save_data()
	check(structured_save.get("hotbar", [])[0] == {"kind": "item", "id": CONVEYOR.id})

	InventoryManager.get_inventory().move_slot(0, 1)
	check(ToolManager.get_tool_in_slot(0) == equipped)
	check(ToolManager.consume_placeable_item(CONVEYOR.id))
	check(InventoryManager.get_inventory().get_extractable_quantity(CONVEYOR.id) == 1)
	check(ToolManager.get_tool_in_slot(0) == equipped)

	GameStateManager.set_creative_mode(true)
	var creative_entries := ToolManager.get_all_tools()
	check(creative_entries.has("item:%s" % CONVEYOR.id))
	check(creative_entries.has("item:9"))
	var creative_conveyor := creative_entries.get("item:%s" % CONVEYOR.id) as HotbarBinding
	check(creative_conveyor != null and creative_conveyor.get_display_name() == "Conveyor")
	GameStateManager.set_creative_mode(false)
	var normal_entries := ToolManager.get_all_tools()
	for tool_id in ["collect", "destruct", "item"]:
		var normal_tool := normal_entries.get(tool_id) as ToolResource
		check(normal_tool != null and not normal_tool.name.is_empty() and not normal_tool.tool_script_path.is_empty())
		check(ToolManager.equip_tool(tool_id, 0))
		var normal_binding := ToolManager.get_tool_in_slot(0) as HotbarBinding
		check(normal_tool != null and normal_binding != null and normal_binding.get_display_name() == normal_tool.name and not normal_binding.tool_script_path.is_empty())

	ToolManager.load_save_data({"hotbar": [CONVEYOR.id, "collect", "unknown_hotbar_id"]})
	var migrated_item := ToolManager.get_tool_in_slot(0) as ItemPlacementToolResource
	var migrated_tool := ToolManager.get_tool_in_slot(1) as HotbarBinding
	check(migrated_item != null and migrated_item.binding_id == CONVEYOR.id)
	check(migrated_tool != null and migrated_tool.kind == HotbarBinding.KIND_TOOL and migrated_tool.binding_id == "collect")
	check(ToolManager.get_tool_in_slot(2) == null)

	check(InventoryManager.remove_item(CONVEYOR, 1) == 1)
	check(ToolManager.get_tool_in_slot(0) == null)
	check(not ToolManager.is_tool_available("conveyor"))

	ToolManager.clear_save_data()
	InventoryManager.clear_save_data()

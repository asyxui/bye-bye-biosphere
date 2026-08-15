## Headless smoke tests for construction affordability and refunds.
extends SceneTree

func _initialize() -> void:
	GameStateManager.set_creative_mode(false)
	var inventory := Inventory.new(2)
	var ingot: InventoryItem = ItemUtils.item_object_by_id("3")
	assert(ingot != null)
	assert(inventory.add_item(ingot, 8) == 0)

	var construction_cost: Dictionary = {"3": 4}
	assert(ConstructionCosts.can_afford(construction_cost, inventory))
	assert(ConstructionCosts.consume(construction_cost, inventory))
	assert(inventory.get_extractable_quantity("3") == 4)

	var failed_cost: Dictionary = {"3": 5}
	assert(not ConstructionCosts.can_afford(failed_cost, inventory))
	assert(not ConstructionCosts.consume(failed_cost, inventory))
	assert(inventory.get_extractable_quantity("3") == 4)

	ConstructionCosts.refund(construction_cost, inventory, Vector3.ZERO)
	assert(inventory.get_extractable_quantity("3") == 8)

	GameStateManager.set_creative_mode(true)
	var creative_inventory := Inventory.new(2)
	assert(creative_inventory.add_item(ingot, 8) == 0)
	assert(ConstructionCosts.can_afford({"3": 99}, creative_inventory))
	assert(ConstructionCosts.consume({"3": 99}, creative_inventory))
	assert(creative_inventory.get_extractable_quantity("3") == 8)
	ConstructionCosts.refund(construction_cost, creative_inventory, Vector3.ZERO)
	assert(creative_inventory.get_extractable_quantity("3") == 8)
	GameStateManager.set_creative_mode(false)
	assert(not ToolManager.is_tool_available("producer"))
	assert(not ToolManager.get_all_tools().has("producer"))
	GameStateManager.set_creative_mode(true)
	assert(ToolManager.is_tool_available("producer"))
	assert(ToolManager.get_all_tools().has("producer"))
	GameStateManager.set_creative_mode(false)
	quit()

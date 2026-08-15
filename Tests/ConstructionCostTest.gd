## Headless smoke tests for construction affordability and refunds.
extends SceneTree

func _initialize() -> void:
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
	quit()

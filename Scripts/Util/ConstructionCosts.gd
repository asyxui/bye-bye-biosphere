## Shared construction-cost operations for placeable structures.
class_name ConstructionCosts
extends RefCounted

static func get_cost(tool_id: String) -> Dictionary:
	var tool: ToolResource = ToolManager.get_tool(tool_id) as ToolResource
	if tool == null:
		return {}
	return tool.construction_cost.duplicate(true)

static func get_missing(cost: Dictionary, inventory: Inventory) -> Dictionary:
	if not GameStateManager.construction_costs_enabled():
		return {}
	var missing: Dictionary = {}
	if inventory == null:
		return cost.duplicate(true)
	for item_key in cost:
		var item_id: String = str(item_key)
		var required: int = int(cost[item_key])
		if required <= 0:
			continue
		var available: int = inventory.get_extractable_quantity(item_id)
		if available < required:
			missing[item_id] = required - available
	return missing

static func can_afford(cost: Dictionary, inventory: Inventory) -> bool:
	if not GameStateManager.construction_costs_enabled():
		return true
	return get_missing(cost, inventory).is_empty()

static func consume(cost: Dictionary, inventory: Inventory) -> bool:
	if not GameStateManager.construction_costs_enabled():
		return true
	if not can_afford(cost, inventory):
		return false
	for item_key in cost:
		if int(cost[item_key]) > 0 and ItemUtils.item_object_by_id(str(item_key)) == null:
			return false
	var removed: Dictionary = {}
	for item_key in cost:
		var item_id: String = str(item_key)
		var required: int = int(cost[item_key])
		if required <= 0:
			continue
		var item: InventoryItem = ItemUtils.item_object_by_id(item_id)
		if item == null or inventory.remove_item(item, required) != required:
			for rollback_key in removed:
				var rollback_item: InventoryItem = ItemUtils.item_object_by_id(str(rollback_key))
				inventory.add_item(rollback_item, int(removed[rollback_key]))
			return false
		removed[item_id] = required
	return true

static func refund(cost: Dictionary, inventory: Inventory, drop_position: Vector3) -> void:
	if not GameStateManager.construction_costs_enabled():
		return
	for item_key in cost:
		var item_id: String = str(item_key)
		var quantity: int = int(cost[item_key])
		if quantity <= 0:
			continue
		var item: InventoryItem = ItemUtils.item_object_by_id(item_id)
		if item == null:
			continue
		var remaining: int = quantity
		if inventory != null:
			remaining = inventory.add_item(item, quantity)
		if remaining > 0:
			MapManager.spawn_item_drop(item, drop_position + Vector3.UP * 1.5, null, remaining)

static func format_requirements(cost: Dictionary) -> String:
	var requirements: Array[String] = []
	for item_key in cost:
		var quantity: int = int(cost[item_key])
		if quantity <= 0:
			continue
		var item: InventoryItem = ItemUtils.item_object_by_id(str(item_key))
		var display_name: String = item.get_display_name() if item != null else str(item_key)
		requirements.append("%d %s" % [quantity, display_name])
	return ", ".join(requirements)

static func format_missing(missing: Dictionary) -> String:
	if missing.is_empty():
		return ""
	return "Missing: " + format_requirements(missing)

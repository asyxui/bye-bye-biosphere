extends Node3D


@export var dropData: InventoryItem
@export var quantity: int = 1

## World pickups keep their existing node/physics implementation, but expose
## the shared logical information needed by collection.
func get_item_id() -> String:
	return str(dropData.id) if dropData != null else ""

func get_item_stack() -> ItemStack:
	return ItemStack.new(dropData, quantity) if dropData != null and quantity > 0 else null

func remove_quantity(amount: int) -> int:
	var removed := mini(maxi(0, amount), quantity)
	quantity -= removed
	if quantity <= 0:
		queue_free()
	return removed

func remove_from_world() -> void:
	queue_free()

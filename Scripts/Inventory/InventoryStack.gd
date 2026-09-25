## InventoryStack.gd
## Represents a stack of items in inventory
class_name InventoryStack
extends ItemStack

func _init(p_item = null, p_quantity: int = 0, p_metadata: Dictionary = {}) -> void:
	super(p_item, p_quantity, p_metadata)
	quantity = clampi(quantity, 0, get_max_stack_size(64))

## Add items to this stack, returns overflow
func add(amount: int) -> int:
	if item_id.is_empty():
		return amount
	
	var new_quantity = quantity + amount
	var stack_limit := get_max_stack_size(64)
	if new_quantity > stack_limit:
		quantity = stack_limit
		return new_quantity - stack_limit
	else:
		quantity = new_quantity
		return 0

## Remove items from stack, returns actual amount removed
func remove(amount: int) -> int:
	var removed = mini(amount, quantity)
	quantity -= removed
	return removed

## Check if stack is empty
func is_empty() -> bool:
	return quantity <= 0

## Get remaining capacity
func get_remaining_capacity() -> int:
	return get_max_stack_size(64) - quantity if not item_id.is_empty() else 0

## Create a copy of this stack
func duplicate_stack() -> InventoryStack:
	var copy := InventoryStack.new(item, quantity, metadata)
	copy.item_id = item_id
	copy.item_resource = item_resource
	return copy

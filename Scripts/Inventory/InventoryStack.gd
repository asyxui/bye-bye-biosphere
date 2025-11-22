## InventoryStack.gd
## Represents a stack of items in inventory
class_name InventoryStack
extends Resource

var item = null  # InventoryItem type
var quantity: int = 0

func _init(p_item = null, p_quantity: int = 0) -> void:
	item = p_item
	quantity = clampi(p_quantity, 0, item.max_stack_size if item else 0)

## Add items to this stack, returns overflow
func add(amount: int) -> int:
	if item == null:
		return amount
	
	var new_quantity = quantity + amount
	if new_quantity > item.max_stack_size:
		quantity = item.max_stack_size
		return new_quantity - item.max_stack_size
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
	return (item.max_stack_size - quantity) if item else 0

## Create a copy of this stack
func duplicate_stack() -> InventoryStack:
	return InventoryStack.new(item, quantity)

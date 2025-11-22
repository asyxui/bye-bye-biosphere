## InventoryInteractions.gd
## Handles user interactions with inventory items
extends Node

## Move item from one slot to another (entire stack)
## Returns true if successful
func move_item(from_slot: int, to_slot: int) -> bool:
	var inventory = InventoryManager.get_inventory()
	
	if from_slot == to_slot:
		return false
	
	var from_stack = inventory.get_slot_item(from_slot)
	var to_stack = inventory.get_slot_item(to_slot)
	
	if from_stack == null or from_stack.is_empty():
		return false
	
	# Moving to empty slot - just swap
	if to_stack.is_empty():
		return inventory.move_slot(from_slot, to_slot)
	
	# Moving to occupied slot with different item - just swap
	if to_stack.item != from_stack.item:
		return inventory.move_slot(from_slot, to_slot)
	
	# Moving to occupied slot with same item - merge/combine
	var transfer_amount = mini(from_stack.quantity, to_stack.get_remaining_capacity())
	if transfer_amount > 0:
		from_stack.remove(transfer_amount)
		to_stack.add(transfer_amount)
		inventory.items_changed.emit()
		return true
	
	return false

## Split a stack into two - move split_amount from from_slot to to_slot
## If to_slot is empty, creates new stack there
## Returns true if successful
func split_item(from_slot: int, to_slot: int, split_amount: int) -> bool:
	var inventory = InventoryManager.get_inventory()
	
	if from_slot == to_slot:
		return false
	
	if split_amount <= 0:
		return false
	
	var from_stack = inventory.get_slot_item(from_slot)
	var to_stack = inventory.get_slot_item(to_slot)
	
	if from_stack == null or from_stack.is_empty():
		return false
	
	# Can't split into slot with different item
	if not to_stack.is_empty() and to_stack.item != from_stack.item:
		return false
	
	# Calculate how much we can actually transfer
	var transfer_amount = mini(split_amount, from_stack.quantity)
	
	if not to_stack.is_empty():
		# Target slot already has items of same type
		var available_space = to_stack.get_remaining_capacity()
		transfer_amount = mini(transfer_amount, available_space)
	
	if transfer_amount <= 0:
		return false
	
	# Perform the split
	from_stack.remove(transfer_amount)
	
	if to_stack.is_empty():
		var new_stack = load("res://Scripts/Inventory/InventoryStack.gd").new(from_stack.item, 0)
		inventory.slots[to_slot] = new_stack
		to_stack = inventory.slots[to_slot]
	
	to_stack.add(transfer_amount)
	inventory.items_changed.emit()
	return true

## Combine all items of the same type together
## Fills up stacks starting from slot 0
## Returns true if any items were combined
func combine_all_items() -> bool:
	var inventory = InventoryManager.get_inventory()
	return inventory.combine_items()

## Combine items of a specific type
## Returns true if any items were combined
func combine_item_type(item) -> bool:
	var inventory = InventoryManager.get_inventory()
	return inventory.combine_items(item)


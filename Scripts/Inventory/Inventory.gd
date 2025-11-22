## Inventory.gd
## Core inventory manager - handles storing and managing items
class_name Inventory
extends Resource

signal items_changed()  ## Emitted when inventory contents change
signal item_added(item, quantity: int, slot_index: int)
signal item_removed(item, quantity: int, slot_index: int)
signal item_moved(from_slot: int, to_slot: int)

@export var inventory_size: int = 20  ## Total number of slots
var slots: Array = []
var max_weight: float = 100.0  ## Max carrying capacity

func _init(p_size: int = 20) -> void:
	inventory_size = p_size
	_initialize_slots()

## Initialize all slots as empty
func _initialize_slots() -> void:
	slots.clear()
	for i in range(inventory_size):
		# Create new InventoryStack instances
		var stack = load("res://Scripts/Inventory/InventoryStack.gd").new()
		slots.append(stack)

## Try to add item to inventory, returns amount that couldn't fit
func add_item(item, quantity: int) -> int:
	if quantity <= 0 or item == null:
		return 0
	
	var remaining = quantity
	
	# First try to add to existing stacks
	for i in range(inventory_size):
		if remaining <= 0:
			break
		
		if slots[i].item == item and not slots[i].is_empty():
			remaining = slots[i].add(remaining)
	
	# Then fill empty slots
	if remaining > 0:
		for i in range(inventory_size):
			if remaining <= 0:
				break
			
			if slots[i].is_empty():
				var stack = load("res://Scripts/Inventory/InventoryStack.gd").new(item, 0)
				slots[i] = stack
				remaining = slots[i].add(remaining)
	
	if remaining < quantity:
		item_added.emit(item, quantity - remaining, find_item_slot(item))
		items_changed.emit()
	
	return remaining

## Remove item from inventory, returns actual amount removed
func remove_item(item, quantity: int) -> int:
	var removed = 0
	
	for i in range(inventory_size):
		if quantity <= 0:
			break
		
		if slots[i].item == item:
			var removed_now = slots[i].remove(quantity)
			removed += removed_now
			quantity -= removed_now
	
	if removed > 0:
		item_removed.emit(item, removed, find_item_slot(item))
		items_changed.emit()
	
	return removed

## Get quantity of specific item in inventory
func get_item_count(item) -> int:
	var count = 0
	for i in range(inventory_size):
		if slots[i].item == item:
			count += slots[i].quantity
	return count

## Get item at specific slot, null if empty
func get_slot_item(slot_index: int):
	if slot_index >= 0 and slot_index < slots.size():
		return slots[slot_index]
	return null

## Move item from one slot to another
func move_slot(from_index: int, to_index: int) -> bool:
	if from_index < 0 or from_index >= slots.size():
		return false
	if to_index < 0 or to_index >= slots.size():
		return false
	
	var temp = slots[from_index]
	slots[from_index] = slots[to_index]
	slots[to_index] = temp
	
	item_moved.emit(from_index, to_index)
	items_changed.emit()
	return true

## Split a stack into another slot
func split_stack(from_index: int, to_index: int, amount: int) -> bool:
	if from_index < 0 or from_index >= slots.size():
		return false
	if to_index < 0 or to_index >= slots.size():
		return false
	
	var from_stack = slots[from_index]
	var to_stack = slots[to_index]
	
	if from_stack.is_empty():
		return false
	
	if not to_stack.is_empty() and to_stack.item != from_stack.item:
		return false
	
	var transfer_amount = mini(amount, from_stack.quantity)
	from_stack.remove(transfer_amount)
	
	if to_stack.is_empty():
		var stack = load("res://Scripts/Inventory/InventoryStack.gd").new(from_stack.item, 0)
		slots[to_index] = stack
	
	slots[to_index].add(transfer_amount)
	
	items_changed.emit()
	return true

## Find first slot with specific item
func find_item_slot(item) -> int:
	for i in range(inventory_size):
		if slots[i].item == item:
			return i
	return -1

## Get inventory weight
func get_total_weight() -> float:
	var total = 0.0
	for slot in slots:
		if slot.item and not slot.is_empty():
			total += slot.item.weight * slot.quantity
	return total

## Check if inventory is full
func is_full() -> bool:
	for slot in slots:
		if slot.is_empty():
			return false
	return true

## Check if inventory is at weight limit
func is_at_weight_limit() -> bool:
	return get_total_weight() >= max_weight

## Get remaining slots
func get_empty_slots() -> int:
	var count = 0
	for slot in slots:
		if slot.is_empty():
			count += 1
	return count

## Clear all inventory
func clear_inventory() -> void:
	_initialize_slots()
	items_changed.emit()

## Get all unique items in inventory
func get_unique_items() -> Array:
	var items: Array = []
	for slot in slots:
		if slot.item and items.find(slot.item) == -1:
			items.append(slot.item)
	return items

## Combine similar items together, respecting stack limits
## Returns true if any items were combined
func combine_items(item = null) -> bool:
	var combined = false
	var target_item = item
	
	# If no item specified, combine all item types
	if target_item == null:
		for unique_item in get_unique_items():
			if _combine_single_item_type(unique_item):
				combined = true
	else:
		if _combine_single_item_type(target_item):
			combined = true
	
	if combined:
		items_changed.emit()
	
	return combined

## Internal helper to combine a single item type
func _combine_single_item_type(item) -> bool:
	var combined = false
	var item_slots: Array = []
	
	# Find all slots with this item
	for i in range(inventory_size):
		if slots[i].item == item:
			item_slots.append(i)
	
	if item_slots.size() <= 1:
		return false
	
	# Combine from later slots into earlier slots
	for i in range(item_slots.size() - 1, 0, -1):
		var from_index = item_slots[i]
		var from_stack = slots[from_index]
		
		# Try to pour into each earlier slot
		for j in range(i):
			var to_index = item_slots[j]
			var to_stack = slots[to_index]
			
			if to_stack.get_remaining_capacity() > 0:
				var transfer_amount = mini(from_stack.quantity, to_stack.get_remaining_capacity())
				from_stack.remove(transfer_amount)
				to_stack.add(transfer_amount)
				combined = true
				
				if from_stack.is_empty():
					break
	
	return combined


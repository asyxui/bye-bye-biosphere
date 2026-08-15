## Inventory.gd
## Core inventory manager - handles storing and managing items
class_name Inventory
extends ItemStorage

signal items_changed() ## Emitted when inventory contents change
signal item_added(item, quantity: int, slot_index: int)
signal item_removed(item, quantity: int, slot_index: int)
signal item_moved(from_slot: int, to_slot: int)

@export var inventory_size: int = 20 ## Total number of slots
var slots: Array = []
var max_weight: float = 100.0 ## Max carrying capacity

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
		return quantity
	var incoming := InventoryStack.new(item, quantity)
	var inserted := insert_stack(incoming)
	var remaining := quantity - inserted
	if inserted > 0:
		item_added.emit(item, inserted, find_item_slot(item))
		items_changed.emit()
	return remaining

func get_insertable_quantity(stack: ItemStack, quantity: int = -1) -> int:
	if stack == null or stack.item_id.is_empty() or stack.quantity <= 0:
		return 0
	var requested := stack.quantity if quantity < 0 else mini(quantity, stack.quantity)
	if requested <= 0:
		return 0
	var remaining := 0
	for slot in slots:
		if not slot.is_empty() and slot.is_same_item(stack) and slot.metadata == stack.metadata:
			remaining += slot.get_remaining_capacity()
	for slot in slots:
		if slot.is_empty():
			remaining += stack.get_max_stack_size(64)
	return mini(requested, maxi(0, remaining))

func insert_stack(stack: ItemStack, quantity: int = -1) -> int:
	var accepted := get_insertable_quantity(stack, quantity)
	if accepted <= 0:
		return 0
	stack.quantity -= accepted
	var remaining := accepted
	for slot in slots:
		if remaining <= 0:
			break
		if not slot.is_empty() and slot.is_same_item(stack) and slot.metadata == stack.metadata:
			var moved := mini(remaining, slot.get_remaining_capacity())
			slot.quantity += moved
			remaining -= moved
	for index in range(slots.size()):
		if remaining <= 0:
			break
		if slots[index].is_empty():
			var destination := InventoryStack.new(stack.item, 0, stack.metadata)
			destination.item_id = stack.item_id
			destination.item_resource = stack.item_resource
			slots[index] = destination
			var moved := mini(remaining, destination.get_max_stack_size(64))
			destination.quantity = moved
			remaining -= moved
	if remaining != 0:
		stack.quantity += remaining
		push_error("Inventory insertion invariant failed; restored uninserted items")
	return accepted - remaining

func can_extract(item_id: String, quantity: int = 1) -> bool:
	return quantity > 0 and get_extractable_quantity(item_id) >= quantity

func get_extractable_quantity(item_id: String) -> int:
	if item_id.is_empty():
		return 0
	var total := 0
	for slot in slots:
		if not slot.is_empty() and slot.item_id == item_id:
			total += slot.quantity
	return total

func extract_stack(item_id: String, quantity: int) -> ItemStack:
	if quantity <= 0 or not can_extract(item_id, 1):
		return null
	var remaining := mini(quantity, get_extractable_quantity(item_id))
	var extracted: ItemStack = null
	for index in range(slots.size() - 1, -1, -1):
		if remaining <= 0:
			break
		var source: InventoryStack = slots[index]
		if source.is_empty() or source.item_id != item_id:
			continue
		var moved := mini(remaining, source.quantity)
		if extracted == null:
			extracted = ItemStack.new(source.item_id, 0, source.metadata)
			extracted.item_resource = source.item_resource
		extracted.quantity += moved
		source.quantity -= moved
		remaining -= moved
		if source.quantity <= 0:
			slots[index] = InventoryStack.new()
	return extracted

func peek_stack(item_id: String = "") -> ItemStack:
	for slot in slots:
		if not slot.is_empty() and (item_id.is_empty() or slot.item_id == item_id):
			return slot.duplicate_stack()
	return null

## Remove item from inventory, returns actual amount removed
func remove_item(item, quantity: int) -> int:
	if item == null or quantity <= 0:
		return 0
	var removed_stack := extract_stack(str(item.id), quantity)
	var removed := removed_stack.quantity if removed_stack != null else 0
	if removed > 0:
		item_removed.emit(item, removed, find_item_slot(item))
		items_changed.emit()

	return removed

## Get quantity of specific item in inventory
func get_item_count(item) -> int:
	var count = 0
	for i in range(inventory_size):
		if not slots[i].is_empty() and slots[i].item_id == str(item.id):
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

	if not to_stack.is_empty() and not to_stack.is_same_item(from_stack):
		return false

	var transfer_amount = mini(amount, from_stack.quantity)
	from_stack.remove(transfer_amount)

	if to_stack.is_empty():
		var stack = load("res://Scripts/Inventory/InventoryStack.gd").new(from_stack.item, 0, from_stack.metadata)
		slots[to_index] = stack

	slots[to_index].add(transfer_amount)

	items_changed.emit()
	return true

## Find first slot with specific item
func find_item_slot(item) -> int:
	for i in range(inventory_size):
		if not slots[i].is_empty() and slots[i].item_id == str(item.id):
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
	var ids: Array[String] = []
	for slot in slots:
		if slot.item and not slot.is_empty() and ids.find(slot.item_id) == -1:
			items.append(slot.item)
			ids.append(slot.item_id)
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
		if not slots[i].is_empty() and slots[i].item_id == str(item.id):
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

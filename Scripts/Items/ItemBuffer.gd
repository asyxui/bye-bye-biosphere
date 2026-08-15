## Generic logical buffer used by machines and other non-slot owners.
class_name ItemBuffer
extends ItemStorage

@export var slot_capacity: int = 1
@export var stack_capacity: int = 64
var stacks: Array[ItemStack] = []

func _init(p_slot_capacity: int = 1, p_stack_capacity: int = 64) -> void:
	slot_capacity = maxi(0, p_slot_capacity)
	stack_capacity = maxi(1, p_stack_capacity)

func get_insertable_quantity(stack: ItemStack, quantity: int = -1) -> int:
	if stack == null or stack.item_id.is_empty() or stack.quantity <= 0:
		return 0
	var requested := stack.quantity if quantity < 0 else mini(quantity, stack.quantity)
	if requested <= 0:
		return 0

	var remaining := 0
	for existing in stacks:
		if existing.is_same_item(stack) and existing.metadata == stack.metadata:
			remaining += _stack_limit(stack) - existing.quantity
	if stacks.size() < slot_capacity:
		remaining += (slot_capacity - stacks.size()) * _stack_limit(stack)
	return mini(requested, maxi(0, remaining))

func insert_stack(stack: ItemStack, quantity: int = -1) -> int:
	var accepted := get_insertable_quantity(stack, quantity)
	if accepted <= 0:
		return 0

	# Remove from the incoming owner before creating destination state.
	stack.quantity -= accepted
	var remaining := accepted
	for existing in stacks:
		if remaining <= 0:
			break
		if existing.is_same_item(stack) and existing.metadata == stack.metadata:
			var moved := mini(remaining, _stack_limit(existing) - existing.quantity)
			existing.quantity += moved
			remaining -= moved

	while remaining > 0 and stacks.size() < slot_capacity:
		var moved := mini(remaining, _stack_limit(stack))
		var destination := ItemStack.new(stack.item_id, moved, stack.metadata)
		destination.item_resource = stack.item_resource
		stacks.append(destination)
		remaining -= moved

	if remaining != 0:
		# This is defensive only: the preflight above should make this impossible.
		stack.quantity += remaining
		push_error("ItemBuffer insertion invariant failed; restored uninserted items")
	return accepted - remaining

func can_extract(item_id: String, quantity: int = 1) -> bool:
	return quantity > 0 and get_extractable_quantity(item_id) >= quantity

func get_extractable_quantity(item_id: String) -> int:
	if item_id.is_empty():
		return 0
	var total := 0
	for stack in stacks:
		if stack.item_id == item_id:
			total += stack.quantity
	return total

func extract_stack(item_id: String, quantity: int) -> ItemStack:
	if quantity <= 0 or not can_extract(item_id, 1):
		return null
	var remaining := mini(quantity, get_extractable_quantity(item_id))
	var extracted: ItemStack = null
	for index in range(stacks.size() - 1, -1, -1):
		if remaining <= 0:
			break
		var source := stacks[index]
		if source.item_id != item_id:
			continue
		var moved := mini(remaining, source.quantity)
		if extracted == null:
			extracted = ItemStack.new(source.item_id, 0, source.metadata)
			extracted.item_resource = source.item_resource
		extracted.quantity += moved
		source.quantity -= moved
		remaining -= moved
		if source.quantity <= 0:
			stacks.remove_at(index)
	return extracted

func peek_stack(item_id: String = "") -> ItemStack:
	for stack in stacks:
		if item_id.is_empty() or stack.item_id == item_id:
			return stack.duplicate_stack()
	return null

func get_total_quantity() -> int:
	var total := 0
	for stack in stacks:
		total += stack.quantity
	return total

func to_dict() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for stack in stacks:
		data.append({
			"item_id": stack.item_id,
			"quantity": stack.quantity,
			"metadata": stack.metadata
		})
	return data

func load_dict(data: Array) -> void:
	stacks.clear()
	for stack_value in data:
		if not stack_value is Dictionary:
			continue
		var stack_data: Dictionary = stack_value
		var item_id: String = str(stack_data.get("item_id", ""))
		var quantity: int = int(stack_data.get("quantity", 0))
		if item_id.is_empty() or quantity <= 0:
			continue
		var metadata: Dictionary = stack_data.get("metadata", {})
		var stack := ItemStack.new(ItemUtils.item_object_by_id(item_id), quantity, metadata)
		insert_stack(stack)

func _stack_limit(stack: ItemStack) -> int:
	return mini(stack_capacity, stack.get_max_stack_size(stack_capacity))

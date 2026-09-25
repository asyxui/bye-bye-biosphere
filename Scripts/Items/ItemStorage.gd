## Shared contract for anything that owns logical item stacks.
class_name ItemStorage
extends Resource

## Returns true when at least one item from the supplied stack can be accepted.
## Pass a quantity to check that quantity instead of the whole stack.
func can_accept_stack(stack: ItemStack, quantity: int = -1) -> bool:
	return get_insertable_quantity(stack, quantity) > 0

## Returns true only when the requested quantity can be accepted in full.
func can_accept_all(stack: ItemStack, quantity: int = -1) -> bool:
	var requested := stack.quantity if quantity < 0 and stack != null else quantity
	return requested > 0 and get_insertable_quantity(stack, requested) >= requested

func get_insertable_quantity(_stack: ItemStack, _quantity: int = -1) -> int:
	push_error("ItemStorage.get_insertable_quantity must be implemented by the owner")
	return 0

## Inserts as much as possible and returns the amount inserted.
## The incoming stack is reduced by exactly that amount. If zero is returned,
## the incoming stack is unchanged.
func insert_stack(_stack: ItemStack, _quantity: int = -1) -> int:
	push_error("ItemStorage.insert_stack must be implemented by the owner")
	return 0

## Item identifiers, rather than display names or Resource identity, are used
## for extraction checks.
func can_extract(_item_id: String, _quantity: int = 1) -> bool:
	push_error("ItemStorage.can_extract must be implemented by the owner")
	return false

func get_extractable_quantity(_item_id: String) -> int:
	push_error("ItemStorage.get_extractable_quantity must be implemented by the owner")
	return 0

func extract_stack(_item_id: String, _quantity: int) -> ItemStack:
	push_error("ItemStorage.extract_stack must be implemented by the owner")
	return null

func peek_stack(_item_id: String = "") -> ItemStack:
	push_error("ItemStorage.peek_stack must be implemented by the owner")
	return null


## Shared logical representation of an item stack.
##
## An ItemStack is data only. It is not a world pickup, conveyor model, or
## inventory slot. The owner of the stack is responsible for storing it.
class_name ItemStack
extends Resource

@export var item_id: String = ""
@export var quantity: int = 0
@export var metadata: Dictionary = {}

# Kept as an optional reference for UI and item rules.
var item_resource: Resource = null

var item: Resource:
	get:
		return item_resource
	set(value):
		set_item_resource(value)

func _init(p_item: Variant = null, p_quantity: int = 0, p_metadata: Dictionary = {}) -> void:
	metadata = p_metadata.duplicate(true)
	if p_item is String:
		item_id = p_item
	elif p_item != null:
		set_item_resource(p_item)
	quantity = maxi(0, p_quantity)

func set_item_resource(resource: Resource) -> void:
	item_resource = resource
	if resource == null:
		return
	var resource_id = resource.get("id")
	if resource_id != null:
		item_id = str(resource_id)

func is_valid() -> bool:
	return not item_id.is_empty() and quantity > 0

func is_same_item(other: ItemStack) -> bool:
	return other != null and not item_id.is_empty() and item_id == other.item_id

func get_max_stack_size(default_size: int = 64) -> int:
	if item_resource != null:
		var configured_size = item_resource.get("max_stack_size")
		if configured_size != null:
			return maxi(1, int(configured_size))
	return maxi(1, default_size)

func duplicate_stack() -> ItemStack:
	var copy := ItemStack.new(item_id, quantity, metadata)
	copy.item_resource = item_resource
	return copy

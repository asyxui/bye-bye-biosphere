class_name ConveyorBeltObject
extends ItemStorage

var start: Vector3
var end: Vector3
var belt_id: String
var item: ConveyorItem = null
var start_port_id: String = ""
var end_port_id: String = ""
var start_port: ConnectionPoint = null
var end_port: ConnectionPoint = null
@export var segment_capacity: int = 1
# Runtime-only scene instance. It is deliberately not included in to_dict(),
# so save data remains just the belt's endpoints.
var scene_node: Node

func _init(p_start: Vector3, p_end: Vector3, p_belt_id: String = ""):
	start = p_start
	end = p_end
	belt_id = p_belt_id
	segment_capacity = 1

## ItemStorage contract. The belt owns the logical item; any mesh instance is
## presentation only.
func get_insertable_quantity(stack: ItemStack, quantity: int = -1) -> int:
	if stack == null or stack.item_id.is_empty() or stack.quantity <= 0:
		return 0
	var requested := stack.quantity if quantity < 0 else mini(quantity, stack.quantity)
	if item == null:
		return mini(requested, segment_capacity)
	if not item.is_same_item(stack) or item.metadata != stack.metadata:
		return 0
	return mini(requested, maxi(0, segment_capacity - item.quantity))

func insert_stack(stack: ItemStack, quantity: int = -1) -> int:
	var accepted := get_insertable_quantity(stack, quantity)
	if accepted <= 0:
		return 0
	stack.quantity -= accepted
	if item == null:
		item = ConveyorItem.new(stack.item, accepted, 0.0, stack.metadata)
		item.item_id = stack.item_id
		item.item_resource = stack.item_resource
	else:
		item.quantity += accepted
	return accepted

func can_extract(item_id: String, quantity: int = 1) -> bool:
	return item != null and item.item_id == item_id and quantity > 0 and item.quantity >= quantity

func get_extractable_quantity(item_id: String) -> int:
	return item.quantity if item != null and item.item_id == item_id else 0

func extract_stack(item_id: String, quantity: int) -> ItemStack:
	if quantity <= 0 or not can_extract(item_id, 1):
		return null
	var moved := mini(quantity, item.quantity)
	var extracted := ConveyorItem.new(item.item, moved, item.progress, item.metadata)
	extracted.item_id = item.item_id
	extracted.item_resource = item.item_resource
	item.quantity -= moved
	if item.quantity <= 0:
		item = null
	return extracted

func peek_stack(item_id: String = "") -> ItemStack:
	if item == null or (not item_id.is_empty() and item.item_id != item_id):
		return null
	return item.duplicate_stack()

func advance_item(progress_delta: float) -> bool:
	if item == null:
		return false
	item.progress = clampf(item.progress + progress_delta, 0.0, 1.0)
	return item.progress >= 1.0

func set_endpoint_port(endpoint: int, port: ConnectionPoint) -> void:
	if endpoint == ConnectionPoint.PointType.START:
		start_port = port
		start_port_id = port.port_id if port != null else ""
	else:
		end_port = port
		end_port_id = port.port_id if port != null else ""

func clear_endpoint_port(endpoint: int) -> void:
	if endpoint == ConnectionPoint.PointType.START:
		start_port = null
		start_port_id = ""
	else:
		end_port = null
		end_port_id = ""
	
func to_dict() -> Dictionary:
	return {
		"id": belt_id,
		"start": [start.x, start.y, start.z],
		"end": [end.x, end.y, end.z],
		"start_port_id": start_port_id,
		"end_port_id": end_port_id
	}

static func from_dict(d: Dictionary) -> ConveyorBeltObject:
	if not d.has("start") or not d.has("end"):
		push_error("Invalid conveyor belt JSON entry: %s" % d)
		return null

	return ConveyorBeltObject.new(
		Vector3(d["start"][0], d["start"][1], d["start"][2]),
		Vector3(d["end"][0], d["end"][1], d["end"][2]),
		str(d.get("id", ""))
	)

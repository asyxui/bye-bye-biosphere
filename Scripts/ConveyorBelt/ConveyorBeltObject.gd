class_name ConveyorBeltObject
extends ItemStorage

const DEFAULT_SPEED: float = 2.0
const DEFAULT_ITEM_SPACING: float = 1.0
const POSITION_EPSILON: float = 0.0001

var start: Vector3
var end: Vector3
var belt_id: String

## Items are ordered from the belt's leading edge to its start.
var items: Array[ConveyorItem] = []

var start_port_id: String = ""
var end_port_id: String = ""
var downstream_belt_id: String = ""
var construction_cost_paid: bool = false
var start_port: ConnectionPoint = null
var end_port: ConnectionPoint = null
@export var speed: float = DEFAULT_SPEED
@export var item_spacing: float = DEFAULT_ITEM_SPACING

# Runtime-only scene instance. It is deliberately not included in to_dict(),
# so save data remains just the belt's endpoints, connections, and item data.
var scene_node: Node

func _init(p_start: Vector3, p_end: Vector3, p_belt_id: String = "") -> void:
	start = p_start
	end = p_end
	belt_id = p_belt_id
	speed = DEFAULT_SPEED
	item_spacing = DEFAULT_ITEM_SPACING

func get_length() -> float:
	return start.distance_to(end)

func get_spacing_progress() -> float:
	var length: float = get_length()
	if length <= POSITION_EPSILON:
		return 1.0
	return minf(1.0, item_spacing / length)

func get_max_item_count() -> int:
	if item_spacing <= POSITION_EPSILON:
		return 1
	return maxi(1, floori(get_length() / item_spacing) + 1)

func has_start_space() -> bool:
	if items.is_empty():
		return true
	return items.back().progress >= get_spacing_progress() - POSITION_EPSILON

## ItemStorage contract. A belt accepts one logical item per simulation input
## opportunity, and only when its start has enough spacing for that item.
func get_insertable_quantity(stack: ItemStack, quantity: int = -1) -> int:
	if stack == null or stack.item_id.is_empty() or stack.quantity <= 0:
		return 0
	var requested: int = stack.quantity if quantity < 0 else mini(quantity, stack.quantity)
	if requested <= 0 or items.size() >= get_max_item_count() or not has_start_space():
		return 0
	return 1

func insert_stack(stack: ItemStack, quantity: int = -1) -> int:
	var accepted: int = get_insertable_quantity(stack, quantity)
	if accepted <= 0:
		return 0

	stack.quantity -= accepted
	var new_item: ConveyorItem = ConveyorItem.new(
		stack.item_resource if stack.item_resource != null else stack.item_id,
		accepted,
		0.0,
		stack.metadata
	)
	new_item.item_id = stack.item_id
	new_item.item_resource = stack.item_resource
	items.append(new_item)
	return accepted

## Extraction is always from the leading item so items cannot overtake one
## another through the shared transfer contract.
func can_extract(item_id: String, quantity: int = 1) -> bool:
	return not items.is_empty() and items[0].item_id == item_id and quantity > 0 and items[0].quantity >= quantity

func get_extractable_quantity(item_id: String) -> int:
	if items.is_empty() or items[0].item_id != item_id:
		return 0
	return items[0].quantity

func extract_stack(item_id: String, quantity: int) -> ItemStack:
	if quantity <= 0 or not can_extract(item_id, 1):
		return null

	var leading: ConveyorItem = items[0]
	var moved: int = mini(quantity, leading.quantity)
	var extracted: ConveyorItem = ConveyorItem.new(
		leading.item_resource if leading.item_resource != null else leading.item_id,
		moved,
		leading.progress,
		leading.metadata
	)
	extracted.item_id = leading.item_id
	extracted.item_resource = leading.item_resource
	leading.quantity -= moved
	if leading.quantity <= 0:
		items.remove_at(0)
	return extracted

func peek_stack(item_id: String = "") -> ItemStack:
	if items.is_empty() or (not item_id.is_empty() and items[0].item_id != item_id):
		return null
	return items[0].duplicate_stack()

## Advances all items in a fixed simulation step. The list is traversed from
## front to back, so each item is clamped behind the item ahead of it.
func advance_items(delta: float) -> void:
	if items.is_empty() or delta <= 0.0:
		return
	var length: float = maxf(get_length(), POSITION_EPSILON)
	var progress_delta: float = maxf(0.0, speed) * delta / length
	var spacing_progress: float = get_spacing_progress()
	var previous_progress: float = 1.0
	for index in range(items.size()):
		var current: ConveyorItem = items[index]
		var upper_bound: float = 1.0
		if index > 0:
			upper_bound = maxf(0.0, previous_progress - spacing_progress)
		var target: float = minf(1.0, current.progress + progress_delta)
		current.progress = maxf(current.progress, minf(target, upper_bound))
		previous_progress = current.progress

## Pulls one item from the connected producer/output buffer when the start has
## room. ItemTransfer performs the source-first atomic transfer.
func pull_from_connected_source() -> int:
	if start_port == null or start_port.port_direction != ConnectionPoint.PortDirection.OUTPUT or not has_start_space():
		return 0
	var source_node: Node = start_port.get_owner_structure()
	if source_node == null or not source_node.has_method("get_output_buffer"):
		return 0
	var source: ItemStorage = source_node.get_output_buffer() as ItemStorage
	if source == null:
		return 0
	var source_stack: ItemStack = source.peek_stack()
	if source_stack == null or not start_port.accepts_item(source_stack.item_id):
		return 0
	return ItemTransfer.transfer(source, self, source_stack.item_id, 1)

## Attempts to deliver the leading item. A blocked destination leaves the item
## at progress 1.0, which naturally blocks every item behind it.
func transfer_leading_item() -> int:
	if items.is_empty() or items[0].progress < 1.0 - POSITION_EPSILON:
		return 0

	var destination: ItemStorage = null
	if end_port != null:
		if end_port.port_direction != ConnectionPoint.PortDirection.INPUT or not end_port.accepts_item(items[0].item_id):
			return 0
		var destination_node: Node = end_port.get_owner_structure()
		if destination_node != null and destination_node.has_method("get_input_buffer"):
			destination = destination_node.get_input_buffer() as ItemStorage
	else:
		var downstream: ConveyorBeltObject = ConveyorConnectionManager.get_downstream_belt(self)
		if downstream != null:
			destination = downstream

	if destination == null:
		return 0
	return ItemTransfer.transfer(self, destination, items[0].item_id, 1)

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
	var saved_items: Array[Dictionary] = []
	for belt_item in items:
		saved_items.append({
			"item_id": belt_item.item_id,
			"quantity": belt_item.quantity,
			"progress": belt_item.progress,
			"metadata": belt_item.metadata
		})
	return {
		"id": belt_id,
		"start": [start.x, start.y, start.z],
		"end": [end.x, end.y, end.z],
		"start_port_id": start_port_id,
		"end_port_id": end_port_id,
		"downstream_belt_id": downstream_belt_id,
		"construction_cost_paid": construction_cost_paid,
		"items": saved_items
	}

static func from_dict(d: Dictionary) -> ConveyorBeltObject:
	if not d.has("start") or not d.has("end"):
		push_error("Invalid conveyor belt JSON entry: %s" % d)
		return null

	var belt := ConveyorBeltObject.new(
		Vector3(d["start"][0], d["start"][1], d["start"][2]),
		Vector3(d["end"][0], d["end"][1], d["end"][2]),
		str(d.get("id", ""))
	)
	belt.downstream_belt_id = str(d.get("downstream_belt_id", ""))
	belt.construction_cost_paid = bool(d.get("construction_cost_paid", true))
	var saved_items: Array = d.get("items", [])
	for saved_item in saved_items:
		if not saved_item is Dictionary:
			continue
		var item_data: Dictionary = saved_item
		var item_id: String = str(item_data.get("item_id", ""))
		var quantity: int = int(item_data.get("quantity", 1))
		if item_id.is_empty() or quantity <= 0:
			continue
		var metadata: Dictionary = item_data.get("metadata", {})
		var belt_item := ConveyorItem.new(item_id, quantity, float(item_data.get("progress", 0.0)), metadata)
		belt_item.item_resource = ItemUtils.item_object_by_id(item_id)
		belt.items.append(belt_item)
	return belt

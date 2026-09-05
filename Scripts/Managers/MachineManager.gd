extends Node

const PRODUCER_SCENE := preload("res://Scenes/Machines/Producer.tscn")
const SINK_SCENE := preload("res://Scenes/Machines/Sink.tscn")
const SMELTER_SCENE := preload("res://Scenes/Machines/Smelter.tscn")
const MANUAL_SMELTER_SCENE := preload("res://Scenes/Machines/ManualSmelter.tscn")
const STRUCTURE_GROUP := "structures"
var machines: Array[Node3D] = []
var _next_machine_id: int = 1
var _pending_machine_states: Array[Dictionary] = []

func _ready() -> void:
	add_to_group("saveable")

func get_machine_scene(machine_type: String) -> PackedScene:
	match machine_type:
		"producer": return PRODUCER_SCENE
		"sink": return SINK_SCENE
		"smelter": return SMELTER_SCENE
		"manual_smelter": return MANUAL_SMELTER_SCENE
	return null

func can_place(machine_type: String, position: Vector3, _rotation_y: float) -> bool:
	return _get_structure_placement_error(machine_type, position).is_empty()

func get_placement_error(machine_type: String, position: Vector3, _rotation_y: float) -> String:
	return _get_structure_placement_error(machine_type, position)

func _get_structure_placement_error(machine_type: String, position: Vector3) -> String:
	if get_machine_scene(machine_type) == null:
		return "Unknown structure"
	for machine in machines:
		if is_instance_valid(machine) and _boxes_overlap(position, machine.global_position):
			return "Too close to another machine"
	for structure in get_tree().get_nodes_in_group(STRUCTURE_GROUP):
		if structure is Node3D and _point_near_structure(position, structure):
			return "Too close to another structure"
	return ""

func place_machine(machine_type: String, position: Vector3, rotation_y: float, state: Dictionary = {}, saved_structure_id: String = "", placement_item_id: String = "", placement_receipt: Dictionary = {}) -> Node3D:
	var is_loading: bool = not saved_structure_id.is_empty()
	var item_backed := not placement_item_id.is_empty()
	if not is_loading and not item_backed and not ToolManager.is_tool_available(machine_type):
		return null
	if not _get_structure_placement_error(machine_type, position).is_empty():
		return null
	var inventory: Inventory = InventoryManager.get_inventory()
	if not is_loading and item_backed and not GameStateManager.is_creative_mode() and inventory.get_extractable_quantity(placement_item_id) <= 0:
		return null
	var receipt: Dictionary = placement_receipt.duplicate(true) if PlacementReceipt.is_valid(placement_receipt) else {}
	if not is_loading and item_backed:
		if not ToolManager.consume_placeable_item(placement_item_id):
			return null
		receipt = PlacementReceipt.create(placement_item_id, 1, not GameStateManager.is_creative_mode(), GameStateManager.is_creative_mode())
	elif not is_loading:
		receipt = PlacementReceipt.create("", 0, false, GameStateManager.is_creative_mode())
	elif receipt.is_empty():
		receipt = PlacementReceipt.create("", 0, false, false)
	var scene = get_machine_scene(machine_type)
	var machine = scene.instantiate() as Node3D
	# Global transforms require the node to be in the scene tree first.
	get_tree().current_scene.add_child(machine)
	machine.global_position = position
	machine.rotation.y = rotation_y
	var structure_id := saved_structure_id if not saved_structure_id.is_empty() else _allocate_machine_id()
	machine.set("structure_id", structure_id)
	machine.set_meta("placement_receipt", receipt)
	machines.append(machine)
	_configure_machine_ports(machine, structure_id)
	if machine.has_method("load_machine_state"):
		machine.load_machine_state(state)
	return machine

func get_machine_by_id(saved_structure_id: String) -> Node3D:
	for machine in machines:
		if is_instance_valid(machine) and str(machine.get("structure_id")) == saved_structure_id:
			return machine
	return null

func _allocate_machine_id() -> String:
	var candidate := "machine_%d" % _next_machine_id
	while get_machine_by_id(candidate) != null:
		_next_machine_id += 1
		candidate = "machine_%d" % _next_machine_id
	_next_machine_id += 1
	return candidate

func _configure_machine_ports(machine: Node3D, structure_id: String) -> void:
	for port in machine.find_children("*", "ConnectionPoint", true, false):
		var connection_point: ConnectionPoint = port as ConnectionPoint
		if connection_point == null:
			continue
		connection_point.configure_machine_port("%s:%s" % [structure_id, connection_point.name], structure_id)

## Dismantle a placed machine and remove it from the registry immediately.
func remove_machine(machine: Node3D, return_materials: bool = true) -> bool:
	if not is_instance_valid(machine) or not machines.has(machine):
		return false
	machines.erase(machine)
	_disconnect_ports(machine)
	if return_materials:
		var receipt: Dictionary = machine.get_meta("placement_receipt", {})
		ToolManager.refund_placement(receipt, machine.global_position)
	machine.remove_from_group("machines")
	machine.remove_from_group(STRUCTURE_GROUP)
	machine.queue_free()
	return true

func _disconnect_ports(machine: Node) -> void:
	for child in machine.find_children("*", "ConnectionPoint", true, false):
		ConveyorConnectionManager.disconnect_port(child)
		if child.has_method("disconnect_port"):
			child.clear_connections()

func _boxes_overlap(a: Vector3, b: Vector3) -> bool:
	return absf(a.x - b.x) < 2.2 and absf(a.z - b.z) < 2.2

func _point_near_structure(position: Vector3, structure: Node3D) -> bool:
	if structure.name == "ConveyorBelt":
		return ConveyorConnectionManager.is_position_near_belt(position, 1.1)
	var local = structure.to_local(position)
	return absf(local.x) < 1.1 and absf(local.z) < 1.5

func get_save_key() -> String:
	return "machines"

func get_save_data() -> Dictionary:
	var data: Array[Dictionary] = []
	for machine in machines:
		if is_instance_valid(machine):
			data.append({"id": str(machine.get("structure_id")), "type": machine.get("machine_type"), "position": {"x": machine.global_position.x, "y": machine.global_position.y, "z": machine.global_position.z}, "rotation_y": machine.rotation.y, "state": machine.call("get_machine_state"), "placement_receipt": machine.get_meta("placement_receipt", {})})
	return {"machines": data}

func load_save_data(data: Dictionary) -> void:
	clear_save_data()
	_pending_machine_states.clear()
	for machine_data in data.get("machines", []):
		var p: Dictionary = machine_data.get("position", {})
		var saved_receipt: Variant = machine_data.get("placement_receipt", {})
		if not PlacementReceipt.is_valid(saved_receipt):
			var legacy_item_id := str(machine_data.get("placeable_item_id", ""))
			if not legacy_item_id.is_empty():
				saved_receipt = PlacementReceipt.create(legacy_item_id, 1, true, false)
		var machine: Node3D = place_machine(
			machine_data.get("type", ""),
			Vector3(p.get("x", 0.0), p.get("y", 0.0), p.get("z", 0.0)),
			machine_data.get("rotation_y", 0.0),
			{},
			str(machine_data.get("id", "")),
			str(machine_data.get("placeable_item_id", "")),
			saved_receipt if saved_receipt is Dictionary else {}
		)
		if machine != null:
			_pending_machine_states.append({"machine": machine, "state": machine_data.get("state", {})})

## Apply buffers and processing state after all machine ports exist and the
## conveyor manager has reconstructed its geometry and port connections.
func restore_machine_states() -> void:
	for pending_state in _pending_machine_states:
		var machine: Node3D = pending_state.get("machine") as Node3D
		if machine != null and is_instance_valid(machine) and machine.has_method("load_machine_state"):
			machine.load_machine_state(pending_state.get("state", {}))
	_pending_machine_states.clear()

func clear_save_data() -> void:
	_pending_machine_states.clear()
	for machine in machines.duplicate():
		remove_machine(machine, false)

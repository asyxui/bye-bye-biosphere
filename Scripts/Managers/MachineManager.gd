extends Node

const PRODUCER_SCENE := preload("res://Scenes/Machines/Producer.tscn")
const SINK_SCENE := preload("res://Scenes/Machines/Sink.tscn")
const SMELTER_SCENE := preload("res://Scenes/Machines/Smelter.tscn")
const STRUCTURE_GROUP := "structures"
var machines: Array[Node3D] = []
var _next_machine_id: int = 1

func _ready() -> void:
	add_to_group("saveable")

func get_machine_scene(machine_type: String) -> PackedScene:
	match machine_type:
		"producer": return PRODUCER_SCENE
		"sink": return SINK_SCENE
		"smelter": return SMELTER_SCENE
	return null

func can_place(machine_type: String, position: Vector3, _rotation_y: float) -> bool:
	if get_machine_scene(machine_type) == null:
		return false
	for machine in machines:
		if is_instance_valid(machine) and _boxes_overlap(position, machine.global_position):
			return false
	for structure in get_tree().get_nodes_in_group(STRUCTURE_GROUP):
		if structure is Node3D and _point_near_structure(position, structure):
			return false
	return true

func place_machine(machine_type: String, position: Vector3, rotation_y: float, state: Dictionary = {}, saved_structure_id: String = "") -> Node3D:
	if not can_place(machine_type, position, rotation_y):
		return null
	var scene = get_machine_scene(machine_type)
	var machine = scene.instantiate() as Node3D
	# Global transforms require the node to be in the scene tree first.
	get_tree().current_scene.add_child(machine)
	machine.global_position = position
	machine.rotation.y = rotation_y
	var structure_id := saved_structure_id if not saved_structure_id.is_empty() else _allocate_machine_id()
	machine.set("structure_id", structure_id)
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
		_return_construction_materials(machine)
	machine.remove_from_group("machines")
	machine.remove_from_group(STRUCTURE_GROUP)
	machine.queue_free()
	return true

func _disconnect_ports(machine: Node) -> void:
	for child in machine.find_children("*", "ConnectionPoint", true, false):
		ConveyorConnectionManager.disconnect_port(child)
		if child.has_method("disconnect_port"):
			child.clear_connections()

func _return_construction_materials(machine: Node3D) -> void:
	if not machine.has_method("get_construction_cost"):
		return
	var cost = machine.get_construction_cost()
	if not cost is Dictionary:
		return
	for item_id in cost:
		var item = ItemUtils.item_object_by_id(str(item_id))
		var quantity := int(cost[item_id])
		if item != null and quantity > 0:
			MapManager.spawn_item_drop(item, machine.global_position + Vector3.UP * 1.5, null, quantity)

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
			data.append({"id": str(machine.get("structure_id")), "type": machine.get("machine_type"), "position": {"x": machine.global_position.x, "y": machine.global_position.y, "z": machine.global_position.z}, "rotation_y": machine.rotation.y, "state": machine.call("get_machine_state")})
	return {"machines": data}

func load_save_data(data: Dictionary) -> void:
	clear_save_data()
	for machine_data in data.get("machines", []):
		var p: Dictionary = machine_data.get("position", {})
		place_machine(machine_data.get("type", ""), Vector3(p.get("x", 0.0), p.get("y", 0.0), p.get("z", 0.0)), machine_data.get("rotation_y", 0.0), machine_data.get("state", {}), str(machine_data.get("id", "")))

func clear_save_data() -> void:
	for machine in machines.duplicate():
		remove_machine(machine, false)

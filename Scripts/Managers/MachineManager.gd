extends Node

const PRODUCER_SCENE := preload("res://Scenes/Machines/Producer.tscn")
const SINK_SCENE := preload("res://Scenes/Machines/Sink.tscn")
const STRUCTURE_GROUP := "structures"
var machines: Array[Node3D] = []

func _ready() -> void:
	add_to_group("saveable")

func get_machine_scene(machine_type: String) -> PackedScene:
	match machine_type:
		"producer": return PRODUCER_SCENE
		"sink": return SINK_SCENE
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

func place_machine(machine_type: String, position: Vector3, rotation_y: float, state: Dictionary = {}) -> Node3D:
	if not can_place(machine_type, position, rotation_y):
		return null
	var scene = get_machine_scene(machine_type)
	var machine = scene.instantiate() as Node3D
	# Global transforms require the node to be in the scene tree first.
	get_tree().current_scene.add_child(machine)
	machine.global_position = position
	machine.rotation.y = rotation_y
	machines.append(machine)
	if machine.has_method("load_machine_state"):
		machine.load_machine_state(state)
	return machine

func _boxes_overlap(a: Vector3, b: Vector3) -> bool:
	return absf(a.x - b.x) < 2.2 and absf(a.z - b.z) < 2.2

func _point_near_structure(position: Vector3, structure: Node3D) -> bool:
	if structure.name == "ConveyorBelt":
		var offset = position - structure.global_position
		var axis = structure.global_transform.basis.x.normalized()
		var sideways = structure.global_transform.basis.z.normalized()
		var half_length = 10.0 * structure.global_transform.basis.x.length()
		return absf(offset.dot(axis)) < half_length + 1.1 and absf(offset.dot(sideways)) < 1.5
	var local = structure.to_local(position)
	return absf(local.x) < 1.1 and absf(local.z) < 1.5

func get_save_key() -> String:
	return "machines"

func get_save_data() -> Dictionary:
	var data: Array[Dictionary] = []
	for machine in machines:
		if is_instance_valid(machine):
			data.append({"type": machine.get("machine_type"), "position": {"x": machine.global_position.x, "y": machine.global_position.y, "z": machine.global_position.z}, "rotation_y": machine.rotation.y, "state": machine.call("get_machine_state")})
	return {"machines": data}

func load_save_data(data: Dictionary) -> void:
	clear_save_data()
	for machine_data in data.get("machines", []):
		var p: Dictionary = machine_data.get("position", {})
		place_machine(machine_data.get("type", ""), Vector3(p.get("x", 0.0), p.get("y", 0.0), p.get("z", 0.0)), machine_data.get("rotation_y", 0.0), machine_data.get("state", {}))

func clear_save_data() -> void:
	for machine in machines:
		if is_instance_valid(machine):
			machine.queue_free()
	machines.clear()

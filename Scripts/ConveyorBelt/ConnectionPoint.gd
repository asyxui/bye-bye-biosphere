extends Node3D
class_name ConnectionPoint

signal port_disconnected

enum PointType { START, END }
enum PortDirection { INPUT, OUTPUT }

@export var point_type: PointType = PointType.START
@export var port_direction: PortDirection = PortDirection.INPUT
@export var is_machine_port: bool = true
@export var accepted_item_ids: Array[String] = []
@export var accept_all_items: bool = true
@export var max_connections: int = 1

var port_id: String = ""
var owner_structure_id: String = ""
var connected_belt_ids: Array[String] = []
var connected_belts: Array = []

func _ready():
	ConveyorConnectionManager.register_point(self)

func _exit_tree():
	if is_machine_port:
		ConveyorConnectionManager.disconnect_port(self)
	ConveyorConnectionManager.unregister_point(self)

func get_forward_dir() -> Vector3:
	return global_transform.basis.z.normalized()

func configure_machine_port(new_port_id: String, structure_id: String) -> void:
	is_machine_port = true
	port_id = new_port_id
	owner_structure_id = structure_id

func can_connect_belt() -> bool:
	return is_machine_port and connected_belt_ids.size() < maxi(1, max_connections)

func accepts_item(item_id: String) -> bool:
	return accept_all_items or accepted_item_ids.has(item_id)

func add_belt_connection(belt_id: String, belt) -> bool:
	if connected_belt_ids.has(belt_id) or not can_connect_belt():
		return false
	connected_belt_ids.append(belt_id)
	connected_belts.append(belt)
	return true

func remove_belt_connection(belt_id: String) -> void:
	var index := connected_belt_ids.find(belt_id)
	if index < 0:
		return
	connected_belt_ids.remove_at(index)
	if index < connected_belts.size():
		connected_belts.remove_at(index)
	port_disconnected.emit()

func get_connected_belt():
	for index in range(connected_belt_ids.size() - 1, -1, -1):
		if index < connected_belts.size() and is_instance_valid(connected_belts[index]):
			return connected_belts[index]
		connected_belt_ids.remove_at(index)
		if index < connected_belts.size():
			connected_belts.remove_at(index)
	return null

func clear_connections() -> void:
	connected_belt_ids.clear()
	connected_belts.clear()
	port_disconnected.emit()

## Managers call this before queue_free so both sides of a connection clear.
func disconnect_port() -> void:
	ConveyorConnectionManager.disconnect_port(self)

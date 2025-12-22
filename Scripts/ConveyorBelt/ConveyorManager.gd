extends Node

var points: Array[Node3D] = []
const SNAP_DISTANCE := 2.0
const CONVEYOR_SCENE_LENGTH = 20.0

var belts: Array[ConveyorBeltObject] = []
var conveyor_scene: PackedScene = preload("res://Scenes/ConveyorBelt/ConveyorBelt.tscn")

func _ready() -> void:
	# Register as saveable
	add_to_group("saveable")

func register_point(p: Node3D):
	points.append(p)

func unregister_point(p: Node3D):
	points.erase(p)
	
func register_belt(belt: ConveyorBeltObject):
	belts.append(belt)

func find_closest_connection(hit_pos: Vector3) -> ConnectionPoint:
	var closest: ConnectionPoint = null
	var closest_dist := SNAP_DISTANCE

	for point in points:
		var dist := point.global_position.distance_to(hit_pos)
		if dist < closest_dist:
			closest = point
			closest_dist = dist

	return closest

## Spawn a conveyor belt at the given positions and register it for saving
func spawn_conveyor(start: Vector3, end: Vector3) -> Node:
	register_belt(ConveyorBeltObject.new(start, end))
	
	var length = start.distance_to(end)
	
	if length < 0.001:
		return null

	var conveyor = conveyor_scene.instantiate()

	var mid = (start + end) / 2.0
	var direction = (end - start).normalized()
	
	var basis = Basis()
	basis.x = direction
	basis.y = Vector3.UP
	basis.z = basis.x.cross(basis.y).normalized()
	basis = basis.orthonormalized()

	var transform = Transform3D(basis, mid)
	conveyor.global_transform = transform
	conveyor.scale.x = length / CONVEYOR_SCENE_LENGTH

	get_tree().current_scene.add_child(conveyor)
	return conveyor

## Saveable interface: get unique save key
func get_save_key() -> String:
	return "conveyors"


## Get conveyor save data
func get_save_data() -> Dictionary:
	var conveyor_data = []
	for belt in belts:
		conveyor_data.append(belt.to_dict())
	return { "belts": conveyor_data }


## Load conveyor belts from save data
func load_save_data(data: Dictionary) -> void:
	# Clear current belts
	belts.clear()
	
	var conveyor_data = data.get("belts", [])
	for belt_dict in conveyor_data:
		var belt = ConveyorBeltObject.from_dict(belt_dict)
		if belt:
			spawn_conveyor(belt.start, belt.end)

## Clear conveyors (called during world transitions)
func clear_save_data() -> void:
	belts.clear()
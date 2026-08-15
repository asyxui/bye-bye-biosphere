extends Node

var points: Array[Node3D] = []
const SNAP_DISTANCE := 2.0
const CONVEYOR_SCENE_LENGTH = 20.0
const MIN_CONVEYOR_LENGTH := 2.0
const MAX_CONVEYOR_LENGTH := 20.0
const MAX_CONVEYOR_SLOPE_DEGREES := 25.0
const CONVEYOR_CLEARANCE := 1.0

var belts: Array[ConveyorBeltObject] = []
var conveyor_scene: PackedScene = preload("res://Scenes/ConveyorBelt/ConveyorBelt.tscn")

func _ready() -> void:
	# Register as saveable
	add_to_group("saveable")

func register_point(p: Node3D):
	if not points.has(p):
		points.append(p)

func unregister_point(p: Node3D):
	points.erase(p)

func register_belt(belt: ConveyorBeltObject):
	if belt != null and not belts.has(belt):
		belts.append(belt)

func find_closest_connection(hit_pos: Vector3) -> ConnectionPoint:
	var closest: ConnectionPoint = null
	var closest_dist := SNAP_DISTANCE

	for point in points.duplicate():
		if not is_instance_valid(point):
			points.erase(point)
			continue
		var dist: float = point.global_position.distance_to(hit_pos)
		if dist < closest_dist:
			closest = point
			closest_dist = dist

	return closest

## Placement validation shared by the conveyor tool and the manager. A
## touching endpoint is allowed so belts can connect to an existing port, but
## the spans themselves may not overlap an existing structure.
func can_place_conveyor(start: Vector3, end: Vector3) -> bool:
	var delta := end - start
	var length := delta.length()
	if length < MIN_CONVEYOR_LENGTH or length > MAX_CONVEYOR_LENGTH:
		return false
	var horizontal_length := Vector2(delta.x, delta.z).length()
	if horizontal_length < 0.001:
		return false
	var slope_degrees := rad_to_deg(atan2(absf(delta.y), horizontal_length))
	if slope_degrees > MAX_CONVEYOR_SLOPE_DEGREES:
		return false

	for machine in get_tree().get_nodes_in_group("machines"):
		if is_instance_valid(machine) and _segment_near_point(start, end, machine.global_position, CONVEYOR_CLEARANCE + 1.0):
			return false

	for belt in belts:
		if not is_instance_valid(belt):
			continue
		if _segments_overlap(start, end, belt.start, belt.end):
			return false
	return true

func is_position_near_belt(position: Vector3, clearance: float = CONVEYOR_CLEARANCE) -> bool:
	for belt in belts:
		if not is_instance_valid(belt):
			continue
		var point := Vector2(position.x, position.z)
		var start_2d := Vector2(belt.start.x, belt.start.z)
		var end_2d := Vector2(belt.end.x, belt.end.z)
		if _point_segment_distance(point, start_2d, end_2d) < clearance:
			var progress := _segment_progress(point, start_2d, end_2d)
			var belt_y := lerpf(belt.start.y, belt.end.y, progress)
			if absf(position.y - belt_y) < 2.5:
				return true
	return false

func _segments_overlap(start_a: Vector3, end_a: Vector3, start_b: Vector3, end_b: Vector3) -> bool:
	var a := Vector2(start_a.x, start_a.z)
	var b := Vector2(end_a.x, end_a.z)
	var c := Vector2(start_b.x, start_b.z)
	var d := Vector2(end_b.x, end_b.z)
	var closest := minf(_point_segment_distance(a, c, d), _point_segment_distance(b, c, d))
	closest = minf(closest, _point_segment_distance(c, a, b))
	closest = minf(closest, _point_segment_distance(d, a, b))
	var intersects = Geometry2D.segment_intersects_segment(a, b, c, d) != null
	if not intersects and closest >= CONVEYOR_CLEARANCE:
		return false

	# Permit a connection where the new span only touches an existing endpoint.
	if a.distance_to(c) < 0.75 or a.distance_to(d) < 0.75:
		return _point_segment_distance(b, c, d) >= CONVEYOR_CLEARANCE
	if b.distance_to(c) < 0.75 or b.distance_to(d) < 0.75:
		return _point_segment_distance(a, c, d) >= CONVEYOR_CLEARANCE
	return true

func _segment_near_point(start: Vector3, end: Vector3, point: Vector3, clearance: float) -> bool:
	var segment_start := Vector2(start.x, start.z)
	var segment_end := Vector2(end.x, end.z)
	var target := Vector2(point.x, point.z)
	return _point_segment_distance(target, segment_start, segment_end) < clearance and absf(point.y - lerpf(start.y, end.y, _segment_progress(target, segment_start, segment_end))) < 2.5

func _point_segment_distance(point: Vector2, start: Vector2, end: Vector2) -> float:
	if start.distance_squared_to(end) < 0.000001:
		return point.distance_to(start)
	var progress := clampf((point - start).dot(end - start) / (end - start).length_squared(), 0.0, 1.0)
	return point.distance_to(start.lerp(end, progress))

func _segment_progress(point: Vector2, start: Vector2, end: Vector2) -> float:
	if start.distance_squared_to(end) < 0.000001:
		return 0.0
	return clampf((point - start).dot(end - start) / (end - start).length_squared(), 0.0, 1.0)

## Spawn a conveyor belt at the given positions and register it for saving
func spawn_conveyor(start: Vector3, end: Vector3) -> Node:
	if not can_place_conveyor(start, end):
		return null
	var length = start.distance_to(end)

	var belt = ConveyorBeltObject.new(start, end)

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
	belt.scene_node = conveyor
	conveyor.set_meta("conveyor_belt_object", belt)
	register_belt(belt)
	return conveyor

## Remove a belt from the live world and registry. Contents are converted to
## world pickups before the scene node is freed.
func remove_conveyor(target, drop_contents: bool = true) -> bool:
	var belt := _resolve_belt(target)
	if belt == null:
		return false
	belts.erase(belt)
	_disconnect_scene_ports(belt.scene_node)
	if drop_contents:
		_drop_belt_contents(belt)
	if is_instance_valid(belt.scene_node):
		belt.scene_node.remove_from_group("structures")
		belt.scene_node.queue_free()
	belt.scene_node = null
	return true

func _resolve_belt(target) -> ConveyorBeltObject:
	if target is ConveyorBeltObject:
		return target if belts.has(target) else null
	for belt in belts:
		if is_instance_valid(belt) and (belt.scene_node == target or (is_instance_valid(target) and belt.scene_node != null and belt.scene_node.is_ancestor_of(target))):
			return belt
	return null

func _disconnect_scene_ports(scene_node: Node) -> void:
	if not is_instance_valid(scene_node):
		return
	for child in scene_node.find_children("*", "ConnectionPoint", true, false):
		ConveyorConnectionManager.unregister_point(child)
		if child.has_method("disconnect_port"):
			child.disconnect_port()

func _drop_belt_contents(belt: ConveyorBeltObject) -> void:
	var stack: ItemStack = belt.extract_stack(belt.item.item_id, belt.item.quantity) if belt.item != null else null
	if stack == null or stack.quantity <= 0:
		return
	var item_resource: InventoryItem = stack.item as InventoryItem
	if item_resource == null:
		item_resource = ItemUtils.item_object_by_id(stack.item_id)
	if item_resource == null:
		push_error("Cannot create dismantling pickup for item id: %s" % stack.item_id)
		return
	var drop_position := belt.start.lerp(belt.end, 0.5) + Vector3.UP * 1.5
	MapManager.spawn_item_drop(item_resource, drop_position, null, stack.quantity)

## Saveable interface: get unique save key
func get_save_key() -> String:
	return "conveyors"


## Get conveyor save data
func get_save_data() -> Dictionary:
	var conveyor_data = []
	for belt in belts:
		if is_instance_valid(belt) and is_instance_valid(belt.scene_node):
			conveyor_data.append(belt.to_dict())
	return { "belts": conveyor_data }


## Load conveyor belts from save data
func load_save_data(data: Dictionary) -> void:
	# Clear current belts
	clear_save_data()
	
	var conveyor_data = data.get("belts", [])
	for belt_dict in conveyor_data:
		var belt = ConveyorBeltObject.from_dict(belt_dict)
		if belt:
			spawn_conveyor(belt.start, belt.end)

## Clear conveyors (called during world transitions)
func clear_save_data() -> void:
	for belt in belts.duplicate():
		remove_conveyor(belt, false)

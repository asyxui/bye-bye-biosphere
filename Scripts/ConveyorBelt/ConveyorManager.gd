extends Node

var points: Array[Node3D] = []
const SNAP_DISTANCE := 2.0
const CONVEYOR_SCENE_LENGTH = 20.0
const MIN_CONVEYOR_LENGTH := 2.0
const MAX_CONVEYOR_LENGTH := 1000.0
const MAX_CONVEYOR_SLOPE_DEGREES := 25.0
const CONVEYOR_CLEARANCE := 1.0
const FIXED_SIMULATION_STEP: float = 1.0 / 60.0
const MAX_SIMULATION_STEPS_PER_FRAME: int = 8
const BELT_ENDPOINT_CONNECTION_DISTANCE: float = 0.75

var belts: Array[ConveyorBeltObject] = []
var conveyor_scene: PackedScene = preload("res://Scenes/ConveyorBelt/ConveyorBelt.tscn")
var _next_belt_id: int = 1
var _simulation_accumulator: float = 0.0

func _ready() -> void:
	# Register as saveable
	add_to_group("saveable")

func _physics_process(delta: float) -> void:
	_simulation_accumulator += maxf(0.0, delta)
	var steps: int = 0
	while _simulation_accumulator >= FIXED_SIMULATION_STEP and steps < MAX_SIMULATION_STEPS_PER_FRAME:
		_simulation_accumulator -= FIXED_SIMULATION_STEP
		_simulate_step(FIXED_SIMULATION_STEP)
		steps += 1
	if steps >= MAX_SIMULATION_STEPS_PER_FRAME:
		_simulation_accumulator = 0.0

func _simulate_step(delta: float) -> void:
	var belt_snapshot: Array[ConveyorBeltObject] = []
	for belt in belts:
		if is_instance_valid(belt):
			belt_snapshot.append(belt)

	# Resolve exits before movement, then move, then pull new items. This keeps
	# transfers deterministic and prevents a newly transferred item from moving
	# through multiple belts in the same fixed tick.
	for belt in belt_snapshot:
		belt.transfer_leading_item()
	for belt in belt_snapshot:
		belt.advance_items(delta)
	for belt in belt_snapshot:
		belt.pull_from_connected_source()

func register_point(p: Node3D):
	if not points.has(p):
		points.append(p)

func unregister_point(p: Node3D):
	points.erase(p)

func register_belt(belt: ConveyorBeltObject):
	if belt != null and not belts.has(belt):
		belts.append(belt)

func find_closest_connection(hit_pos: Vector3) -> ConnectionPoint:
	return find_closest_port(hit_pos)

func find_closest_port(hit_pos: Vector3, desired_direction: int = -1, compatible_with: ConnectionPoint = null) -> ConnectionPoint:
	var closest: ConnectionPoint = null
	var closest_dist := SNAP_DISTANCE
	for point in points.duplicate():
		if not is_instance_valid(point) or not point.is_machine_port:
			continue
		if desired_direction >= 0 and point.port_direction != desired_direction:
			continue
		if not point.can_connect_belt():
			continue
		if compatible_with != null and not _ports_are_compatible(compatible_with, point):
			continue
		var dist: float = point.global_position.distance_to(hit_pos)
		if dist < closest_dist:
			closest = point
			closest_dist = dist
	return closest

func find_port_by_id(saved_port_id: String) -> ConnectionPoint:
	if saved_port_id.is_empty():
		return null
	for point in points:
		if is_instance_valid(point) and point.is_machine_port and point.port_id == saved_port_id:
			return point
	return null

func get_belt_by_id(saved_belt_id: String) -> ConveyorBeltObject:
	for belt in belts:
		if is_instance_valid(belt) and belt.belt_id == saved_belt_id:
			return belt
	return null

func get_belt_for_scene(scene_node: Node) -> ConveyorBeltObject:
	for belt in belts:
		if is_instance_valid(belt) and belt.scene_node == scene_node:
			return belt
	return null

func get_construction_cost() -> Dictionary:
	return ConstructionCosts.get_cost("conveyor")

## A downstream belt is connected when its start endpoint meets this belt's end
## endpoint. Endpoint matching is reconstructed from saved geometry, so the
## logical connection survives scene reloads without a visual dependency.
func get_downstream_belt(belt: ConveyorBeltObject) -> ConveyorBeltObject:
	if belt == null:
		return null
	var closest: ConveyorBeltObject = null
	var closest_distance: float = BELT_ENDPOINT_CONNECTION_DISTANCE
	for candidate in belts:
		if not is_instance_valid(candidate) or candidate == belt:
			continue
		var distance: float = candidate.start.distance_to(belt.end)
		if distance <= closest_distance:
			closest = candidate
			closest_distance = distance
	return closest

func get_connected_belt(port: ConnectionPoint) -> ConveyorBeltObject:
	if port == null:
		return null
	var belt = port.get_connected_belt()
	return belt as ConveyorBeltObject

func connect_belt_endpoint(belt: ConveyorBeltObject, endpoint: int, port: ConnectionPoint) -> bool:
	if belt == null or port == null or not port.is_machine_port or belt.belt_id.is_empty():
		return false
	var expected_direction := ConnectionPoint.PortDirection.OUTPUT if endpoint == ConnectionPoint.PointType.START else ConnectionPoint.PortDirection.INPUT
	if port.port_direction != expected_direction or not port.can_connect_belt():
		return false
	var existing_port: ConnectionPoint = belt.start_port if endpoint == ConnectionPoint.PointType.START else belt.end_port
	if existing_port != null:
		return existing_port == port
	var other_port: ConnectionPoint = belt.end_port if endpoint == ConnectionPoint.PointType.START else belt.start_port
	if other_port != null and not _ports_are_compatible(port, other_port):
		return false
	if not port.add_belt_connection(belt.belt_id, belt):
		return false
	belt.set_endpoint_port(endpoint, port)
	return true

func disconnect_belt_endpoint(belt: ConveyorBeltObject, endpoint: int) -> void:
	if belt == null:
		return
	var port: ConnectionPoint = belt.start_port if endpoint == ConnectionPoint.PointType.START else belt.end_port
	if port != null:
		port.remove_belt_connection(belt.belt_id)
	belt.clear_endpoint_port(endpoint)

func disconnect_port(port: ConnectionPoint) -> void:
	if port == null:
		return
	var belt_ids: Array = port.connected_belt_ids.duplicate()
	for belt_id in belt_ids:
		var belt := get_belt_by_id(belt_id)
		if belt == null:
			continue
		if belt.start_port == port or belt.start_port_id == port.port_id:
			disconnect_belt_endpoint(belt, ConnectionPoint.PointType.START)
		if belt.end_port == port or belt.end_port_id == port.port_id:
			disconnect_belt_endpoint(belt, ConnectionPoint.PointType.END)
	port.clear_connections()

func _ports_are_compatible(first: ConnectionPoint, second: ConnectionPoint) -> bool:
	var output_port: ConnectionPoint = first if first.port_direction == ConnectionPoint.PortDirection.OUTPUT else second
	var input_port: ConnectionPoint = first if first.port_direction == ConnectionPoint.PortDirection.INPUT else second
	if output_port == null or input_port == null:
		return false
	if output_port.accept_all_items or input_port.accept_all_items:
		return true
	for item_id in output_port.accepted_item_ids:
		if input_port.accepted_item_ids.has(item_id):
			return true
	return false

func _allocate_belt_id() -> String:
	var candidate := "belt_%d" % _next_belt_id
	while get_belt_by_id(candidate) != null:
		_next_belt_id += 1
		candidate = "belt_%d" % _next_belt_id
	_next_belt_id += 1
	return candidate

## Returns an empty string when placement is valid, otherwise a player-facing
## reason for the invalid preview state.
func get_conveyor_placement_error(start: Vector3, end: Vector3, check_cost: bool = false) -> String:
	var delta := end - start
	var length: float = delta.length()
	if length < MIN_CONVEYOR_LENGTH:
		return "Too short (minimum %.0f m)" % MIN_CONVEYOR_LENGTH
	if length > MAX_CONVEYOR_LENGTH:
		return "Too long (maximum %.0f m)" % MAX_CONVEYOR_LENGTH
	var horizontal_length: float = Vector2(delta.x, delta.z).length()
	if horizontal_length < 0.001:
		return "Belt must have a horizontal direction"
	var slope_degrees: float = rad_to_deg(atan2(absf(delta.y), horizontal_length))
	if slope_degrees > MAX_CONVEYOR_SLOPE_DEGREES:
		return "Slope is too steep (maximum %.0f°)" % MAX_CONVEYOR_SLOPE_DEGREES

	for machine in get_tree().get_nodes_in_group("machines"):
		if not is_instance_valid(machine):
			continue
		if _segment_near_point(start, end, machine.global_position, CONVEYOR_CLEARANCE + 1.0) and not _segment_has_machine_port_endpoint(machine, start, end):
			return "Too close to a machine"

	for belt in belts:
		if not is_instance_valid(belt):
			continue
		if _segments_overlap(start, end, belt.start, belt.end):
			return "Overlaps another conveyor"
	if check_cost:
		var missing: Dictionary = ConstructionCosts.get_missing(get_construction_cost(), InventoryManager.get_inventory())
		if not missing.is_empty():
			return ConstructionCosts.format_missing(missing)
	return ""

## Placement validation shared by the conveyor tool and the manager. A
## touching endpoint is allowed so belts can connect to an existing port, but
## the spans themselves may not overlap an existing structure.
func can_place_conveyor(start: Vector3, end: Vector3, check_cost: bool = false) -> bool:
	return get_conveyor_placement_error(start, end, check_cost).is_empty()

func _segment_has_machine_port_endpoint(machine: Node, start: Vector3, end: Vector3) -> bool:
	for point in points:
		if not is_instance_valid(point) or not point.is_machine_port:
			continue
		if not machine.is_ancestor_of(point):
			continue
		if point.global_position.distance_to(start) < 0.75 or point.global_position.distance_to(end) < 0.75:
			return true
	return false

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
func spawn_conveyor(start: Vector3, end: Vector3, saved_belt_id: String = "", charge_cost: bool = true) -> Node:
	var is_loading: bool = not saved_belt_id.is_empty()
	if not can_place_conveyor(start, end, false):
		return null
	var construction_cost: Dictionary = get_construction_cost()
	var inventory: Inventory = InventoryManager.get_inventory()
	if charge_cost and not is_loading and not ConstructionCosts.can_afford(construction_cost, inventory):
		return null
	var length = start.distance_to(end)

	var belt_id := saved_belt_id if not saved_belt_id.is_empty() else _allocate_belt_id()
	var belt = ConveyorBeltObject.new(start, end, belt_id)

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
	conveyor.set_meta("conveyor_belt_object", belt)

	get_tree().current_scene.add_child(conveyor)
	belt.scene_node = conveyor
	register_belt(belt)
	if charge_cost and not is_loading and not ConstructionCosts.consume(construction_cost, inventory):
		remove_conveyor(belt, false, false)
		return null
	return conveyor

## Remove a belt from the live world and registry. Contents are converted to
## world pickups before the scene node is freed.
func remove_conveyor(target, drop_contents: bool = true, return_materials: bool = true) -> bool:
	var belt := _resolve_belt(target)
	if belt == null:
		return false
	belts.erase(belt)
	disconnect_belt_endpoint(belt, ConnectionPoint.PointType.START)
	disconnect_belt_endpoint(belt, ConnectionPoint.PointType.END)
	_disconnect_scene_ports(belt.scene_node)
	if drop_contents:
		_drop_belt_contents(belt)
	if return_materials:
		ConstructionCosts.refund(get_construction_cost(), InventoryManager.get_inventory(), belt.start.lerp(belt.end, 0.5))
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
		if child.has_method("clear_connections"):
			child.clear_connections()

func _drop_belt_contents(belt: ConveyorBeltObject) -> void:
	while not belt.items.is_empty():
		var leading: ConveyorItem = belt.items[0]
		var progress: float = leading.progress
		var stack: ItemStack = belt.extract_stack(leading.item_id, leading.quantity)
		if stack == null or stack.quantity <= 0:
			break
		var item_resource: InventoryItem = stack.item_resource as InventoryItem
		if item_resource == null:
			item_resource = ItemUtils.item_object_by_id(stack.item_id)
		if item_resource == null:
			push_error("Cannot create dismantling pickup for item id: %s" % stack.item_id)
			continue
		var drop_position: Vector3 = belt.start.lerp(belt.end, progress) + Vector3.UP * 0.3
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
	var pending_connections: Array[Dictionary] = []
	var conveyor_data = data.get("belts", [])
	for belt_dict in conveyor_data:
		var belt = ConveyorBeltObject.from_dict(belt_dict)
		if belt:
			var scene_node = spawn_conveyor(belt.start, belt.end, belt.belt_id)
			var created_belt := get_belt_for_scene(scene_node)
			if created_belt != null:
				for saved_item in belt.items:
					created_belt.items.append(saved_item)
				created_belt.start_port_id = str(belt_dict.get("start_port_id", ""))
				created_belt.end_port_id = str(belt_dict.get("end_port_id", ""))
				pending_connections.append({"belt_id": created_belt.belt_id, "start_port_id": created_belt.start_port_id, "end_port_id": created_belt.end_port_id})
	if not pending_connections.is_empty():
		call_deferred("_restore_saved_connections", pending_connections)

func _restore_saved_connections(pending_connections: Array[Dictionary]) -> void:
	for connection_data in pending_connections:
		var belt := get_belt_by_id(str(connection_data.get("belt_id", "")))
		if belt == null:
			continue
		var start_port := find_port_by_id(str(connection_data.get("start_port_id", "")))
		var end_port := find_port_by_id(str(connection_data.get("end_port_id", "")))
		if start_port != null:
			connect_belt_endpoint(belt, ConnectionPoint.PointType.START, start_port)
		if end_port != null:
			connect_belt_endpoint(belt, ConnectionPoint.PointType.END, end_port)

## Clear conveyors (called during world transitions)
func clear_save_data() -> void:
	for belt in belts.duplicate():
		remove_conveyor(belt, false, false)

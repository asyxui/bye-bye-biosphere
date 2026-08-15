extends StaticBody3D

const EMIT_INTERVAL := 1.0
const MAX_OUTSTANDING_DROPS := 20
const ORE := preload("res://Resources/Items/Ore.tres")
var machine_type := "producer"
## Logical ports used by machines/conveyors. The existing loose-drop output is
## intentionally left in place for this milestone's compatibility path.
var input_buffer: ItemBuffer = ItemBuffer.new(1, 64)
var output_buffer: ItemBuffer = ItemBuffer.new(4, 64)
var _elapsed := 0.0
var _outstanding: Array[WeakRef] = []
var _had_output_belt := false

func _ready() -> void:
	add_to_group("machines")
	add_to_group("structures")

func get_input_buffer() -> ItemBuffer:
	return input_buffer

func get_output_buffer() -> ItemBuffer:
	return output_buffer

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < EMIT_INTERVAL:
		return
	_elapsed = fmod(_elapsed, EMIT_INTERVAL)
	_prune_outstanding()
	var output_belt = _get_output_belt()
	if output_belt and not _had_output_belt:
		# Items produced before construction are not on the line. Clear them when
		# the line is connected so they cannot keep this new factory stalled.
		_clear_outstanding_drops()
	_had_output_belt = output_belt != null
	if _outstanding.size() >= MAX_OUTSTANDING_DROPS:
		return
	var spawn_position = _get_spawn_position(output_belt)
	if _output_is_occupied(spawn_position):
		return
	var drop = MapManager.spawn_item_drop(ORE, spawn_position, true)
	if drop:
		_outstanding.append(weakref(drop))

func _get_output_belt() -> ConveyorBeltObject:
	for belt in ConveyorConnectionManager.belts:
		if belt.start.distance_to($Output.global_position) < ConveyorConnectionManager.SNAP_DISTANCE:
			return belt
	return null

func _get_spawn_position(output_belt: ConveyorBeltObject) -> Vector3:
	if output_belt:
		var direction = (output_belt.end - output_belt.start).normalized()
		# Release over the belt's first section, rather than at its collision seam.
		return output_belt.start + direction * 0.75 + Vector3.UP * 1.2
	return $DropSpawn.global_position

func _output_is_occupied(spawn_position: Vector3) -> bool:
	var shape := SphereShape3D.new()
	shape.radius = 0.35
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, spawn_position)
	var results = get_world_3d().direct_space_state.intersect_shape(query, 8)
	for result in results:
		var body = result.get("collider")
		if body is RigidBody3D and body.get_parent() is Node3D and body.get_parent().get("dropData") != null:
			return true
	return false

func _prune_outstanding() -> void:
	_outstanding = _outstanding.filter(func(reference): return reference.get_ref() != null)

func _clear_outstanding_drops() -> void:
	for reference in _outstanding:
		var drop = reference.get_ref()
		if drop and is_instance_valid(drop):
			drop.queue_free()
	_outstanding.clear()

func get_machine_state() -> Dictionary:
	return {}

func load_machine_state(_state: Dictionary) -> void:
	pass

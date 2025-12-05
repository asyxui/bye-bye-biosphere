## ConveyorTool.gd
## Multi-step tool for placing conveyor belts with two-click placement and preview

extends "res://Scripts/Tools/BaseTool.gd"

const CONVEYOR_SCENE_LENGTH = 20.0
const RAY_LENGTH = 20.0

var conveyor_scene: PackedScene = preload("res://Scenes/ConveyorBelt/ConveyorBelt.tscn")

# Tool state
var waiting_for_second_press: bool = false
var conveyor_reversal: bool = false
var start_pos: Vector3 = Vector3.ZERO
var preview_conveyor: Node = null

func on_activate(p: Node) -> void:
	super.on_activate(p)
	_reset_state()

func on_execute(_p: Node) -> void:
	_handle_conveyor_click(player)

func on_cancel() -> void:
	if waiting_for_second_press:
		_cleanup_preview()

func on_update(_delta: float) -> void:
	if waiting_for_second_press and preview_conveyor and player:
		var hit_point = _get_center_hit()
		if hit_point == Vector3.ZERO:
			return
		
		var snap_point = ConveyorConnectionManager.find_closest_connection(hit_point)
		if snap_point:
			hit_point = snap_point.global_position
		
		_update_preview_transform(start_pos, hit_point)

func _reset_state() -> void:
	waiting_for_second_press = false
	conveyor_reversal = false
	start_pos = Vector3.ZERO
	_cleanup_preview()

func _handle_conveyor_click(_p: Node) -> void:
	var hit_point = _get_center_hit()
	if hit_point == Vector3.ZERO:
		return
	
	if not waiting_for_second_press:
		_start_conveyor_placement(hit_point)
	else:
		_finalize_conveyor(hit_point)

func _start_conveyor_placement(hit_point: Vector3) -> void:
	waiting_for_second_press = true
	
	# Check for snap points
	var snap_point = ConveyorConnectionManager.find_closest_connection(hit_point)
	if snap_point:
		hit_point = snap_point.global_position
		if snap_point.point_type == ConnectionPoint.PointType.START:
			conveyor_reversal = true
	
	start_pos = hit_point
	_create_preview_conveyor()

func _finalize_conveyor(hit_point: Vector3) -> void:
	waiting_for_second_press = false
	
	# Check for snap points
	var snap_point = ConveyorConnectionManager.find_closest_connection(hit_point)
	if snap_point:
		hit_point = snap_point.global_position
	
	# Spawn the actual conveyor
	if conveyor_reversal:
		_spawn_conveyor(hit_point, start_pos)
	else:
		_spawn_conveyor(start_pos, hit_point)
	
	_cleanup_preview()
	waiting_for_second_press = false

func _create_preview_conveyor() -> void:
	if preview_conveyor != null:
		return
	
	preview_conveyor = conveyor_scene.instantiate()
	preview_conveyor.collision_layer = 0
	
	# Disable collision on the belt
	var belt = preview_conveyor.find_child("Belt") as StaticBody3D
	if belt:
		belt.collision_layer = 0
	
	# Remove connection points from preview
	for cp in preview_conveyor.get_children():
		if cp is ConnectionPoint:
			cp.queue_free()
	
	player.get_tree().current_scene.add_child(preview_conveyor)

func _cleanup_preview() -> void:
	conveyor_reversal = false
	if preview_conveyor:
		preview_conveyor.queue_free()
		preview_conveyor = null
	start_pos = Vector3.ZERO

func _update_preview_transform(start: Vector3, end: Vector3) -> void:
	var length = start.distance_to(end)
	
	if length < 0.001:
		return
	
	var direction = (end - start).normalized()
	var mid = (start + end) / 2.0

	if conveyor_reversal:
		direction = -direction

	var basis = Basis()
	basis.x = direction
	basis.y = Vector3.UP
	basis.z = basis.x.cross(basis.y).normalized()
	basis = basis.orthonormalized()

	var transform = Transform3D(basis, mid)
	preview_conveyor.global_transform = transform
	preview_conveyor.scale.x = length / CONVEYOR_SCENE_LENGTH

func _spawn_conveyor(start: Vector3, end: Vector3) -> void:
	var length = start.distance_to(end)
	
	if length < 0.001:
		return

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

	player.get_tree().current_scene.add_child(conveyor)

func _get_center_hit() -> Vector3:
	if not player:
		return Vector3.ZERO
	
	var camera = player.get_node_or_null("Camera3D")
	if not camera:
		return Vector3.ZERO
	
	var center = player.get_viewport().size / 2
	var from = camera.project_ray_origin(center)
	var to = from + camera.project_ray_normal(center) * RAY_LENGTH
	var space_state = player.get_world_3d().direct_space_state
	
	var exclude = [player]
	if preview_conveyor:
		exclude.append(preview_conveyor)
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = exclude
	var result = space_state.intersect_ray(query)
	
	return result.position if result else Vector3.ZERO

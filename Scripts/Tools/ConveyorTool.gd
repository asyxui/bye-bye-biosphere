## ConveyorTool.gd
## Multi-step tool for placing conveyor belts with two-click placement and preview

extends "res://Scripts/Tools/BaseTool.gd"
class_name ConveyorTool

const RAY_LENGTH = 20.0

var conveyor_scene: PackedScene = preload("res://Scenes/ConveyorBelt/ConveyorBelt.tscn")

# Tool state
var waiting_for_second_press: bool = false
var conveyor_reversal: bool = false
var start_pos: Vector3 = Vector3.ZERO
var preview_conveyor: Node = null
var preview_is_valid: bool = false

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
	# Check for snap points
	var snap_point = ConveyorConnectionManager.find_closest_connection(hit_point)
	if snap_point:
		hit_point = snap_point.global_position
	
	var actual_start := hit_point if conveyor_reversal else start_pos
	var actual_end := start_pos if conveyor_reversal else hit_point
	if not ConveyorConnectionManager.can_place_conveyor(actual_start, actual_end):
		preview_is_valid = false
		_set_preview_color(false)
		return

	# Spawn the actual conveyor only after the same validation used by the preview.
	var spawned = _spawn_conveyor(actual_start, actual_end)
	if spawned == null:
		preview_is_valid = false
		_set_preview_color(false)
		return
	
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
	preview_is_valid = false
	if preview_conveyor:
		preview_conveyor.queue_free()
		preview_conveyor = null
	start_pos = Vector3.ZERO

func _update_preview_transform(start: Vector3, end: Vector3) -> void:
	var length = start.distance_to(end)
	
	if length < 0.001:
		preview_is_valid = false
		_set_preview_color(false)
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
	preview_conveyor.scale.x = length / ConveyorConnectionManager.CONVEYOR_SCENE_LENGTH
	preview_is_valid = ConveyorConnectionManager.can_place_conveyor(start if not conveyor_reversal else end, end if not conveyor_reversal else start)
	_set_preview_color(preview_is_valid)

func _spawn_conveyor(start: Vector3, end: Vector3) -> Node:
	return ConveyorConnectionManager.spawn_conveyor(start, end)

func _set_preview_color(valid: bool) -> void:
	if not is_instance_valid(preview_conveyor):
		return
	var color := Color(0.3, 1.0, 0.4, 0.55) if valid else Color(1.0, 0.2, 0.2, 0.55)
	for child in preview_conveyor.find_children("*", "GeometryInstance3D", true, false):
		var geometry := child as GeometryInstance3D
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = color
		geometry.material_override = material

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

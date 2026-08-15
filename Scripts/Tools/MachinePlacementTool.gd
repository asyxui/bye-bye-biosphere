extends "res://Scripts/Tools/BaseTool.gd"
class_name MachinePlacementTool

const RAY_LENGTH := 20.0
var preview: Node3D
var waiting_for_confirmation := false
var preview_position := Vector3.ZERO
var preview_rotation_y := 0.0
var preview_is_valid := false

func on_activate(p: Node) -> void:
	super.on_activate(p)
	_cleanup_preview()

func on_execute(_p: Node) -> void:
	var hit = _get_center_hit()
	if hit == Vector3.ZERO:
		return
	if not waiting_for_confirmation:
		waiting_for_confirmation = true
		_create_preview(hit)
	elif MachineManager.place_machine(_tool_resource.id, preview_position, preview_rotation_y):
		_cleanup_preview()

func on_cancel() -> void:
	_cleanup_preview()

func on_update(_delta: float) -> void:
	if waiting_for_confirmation:
		var hit = _get_center_hit()
		if hit != Vector3.ZERO:
			_update_preview(hit)

func _create_preview(position: Vector3) -> void:
	preview = MachineManager.get_machine_scene(_tool_resource.id).instantiate() as Node3D
	if preview is CollisionObject3D:
		preview.set_collision_layer_value(1, false)
		preview.set_collision_mask_value(1, false)
	preview.process_mode = Node.PROCESS_MODE_DISABLED
	player.get_tree().current_scene.add_child(preview)
	preview.remove_from_group("structures")
	preview_is_valid = not MachineManager.can_place(_tool_resource.id, position, 0.0)
	_update_preview(position)

func _update_preview(position: Vector3) -> void:
	preview_position = position
	var direction = player.get_direction()
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		direction = direction.normalized()
		preview_rotation_y = atan2(-direction.x, -direction.z)
	preview.global_position = preview_position
	preview.rotation.y = preview_rotation_y
	var valid = MachineManager.can_place(_tool_resource.id, preview_position, preview_rotation_y)
	if valid != preview_is_valid:
		preview_is_valid = valid
		_set_preview_color(valid)

func _set_preview_color(valid: bool) -> void:
	var color = Color(0.3, 1.0, 0.4, 0.5) if valid else Color(1.0, 0.2, 0.2, 0.5)
	for child in preview.find_children("*", "MeshInstance3D", true, false):
		var mesh = child as MeshInstance3D
		if mesh.material_override is StandardMaterial3D:
			var material = mesh.material_override.duplicate() as StandardMaterial3D
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color = color
			mesh.material_override = material

func _cleanup_preview() -> void:
	waiting_for_confirmation = false
	preview_is_valid = false
	if is_instance_valid(preview):
		preview.queue_free()
	preview = null

func _get_center_hit() -> Vector3:
	var camera = player.get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		return Vector3.ZERO
	var center = player.get_viewport().size * 0.5
	var from = camera.project_ray_origin(center)
	var query = PhysicsRayQueryParameters3D.create(from, from + camera.project_ray_normal(center) * RAY_LENGTH)
	query.exclude = [player]
	if is_instance_valid(preview):
		query.exclude.append(preview)
	var result = player.get_world_3d().direct_space_state.intersect_ray(query)
	return result.position if result else Vector3.ZERO

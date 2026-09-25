extends "res://Scripts/Tools/BaseTool.gd"
class_name MachinePlacementTool

const RAY_LENGTH := 20.0
var preview: Node3D
var waiting_for_confirmation := false
var preview_position := Vector3.ZERO
var preview_rotation_y := 0.0
var preview_is_valid := false
var _preview_materials: Array[StandardMaterial3D] = []

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
	elif preview_is_valid:
		var machine_type := _get_machine_type()
		var placed_machine: Node3D = MachineManager.place_machine(machine_type, preview_position, preview_rotation_y, {}, "", _get_placeable_item_id())
		if placed_machine != null:
			_cleanup_preview()
			if not _get_placeable_item_id().is_empty():
				ToolManager.notify_placeable_placed(_get_placeable_item_id())
		else:
			var placement_error: String = MachineManager.get_placement_error(machine_type, preview_position, preview_rotation_y)
			_set_preview_color(false, placement_error if not placement_error.is_empty() else "Cannot place structure")

func on_cancel() -> void:
	_cleanup_preview()

func on_update(_delta: float) -> void:
	if waiting_for_confirmation:
		var hit = _get_center_hit()
		if hit != Vector3.ZERO:
			_update_preview(hit)

func _prepare_preview_materials() -> void:
	_preview_materials.clear()

	for child in preview.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh.material_override is StandardMaterial3D:
			var material := mesh.material_override.duplicate() as StandardMaterial3D
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mesh.material_override = material
			_preview_materials.append(material)

func _create_preview(position: Vector3) -> void:
	var machine_scene: PackedScene = MachineManager.get_machine_scene(_get_machine_type()) if _tool_resource != null else null
	if machine_scene == null:
		waiting_for_confirmation = false
		preview_is_valid = false
		UIManager.set_placement_status("Cannot place structure: scene not found", false)
		return

	preview = machine_scene.instantiate() as Node3D

	if preview is CollisionObject3D:
		preview.set_collision_layer_value(1, false)
		preview.set_collision_mask_value(1, false)
		preview.process_mode = Node.PROCESS_MODE_DISABLED

	player.get_tree().current_scene.add_child(preview)
	preview.remove_from_group("structures")
	preview.remove_from_group("machines")
	_prepare_preview_materials()
	preview_is_valid = false
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
	var placement_error := ToolManager.get_placeable_availability_error(_tool_resource as ItemPlacementToolResource) if _tool_resource is ItemPlacementToolResource else ""
	if placement_error.is_empty():
		placement_error = MachineManager.get_placement_error(_get_machine_type(), preview_position, preview_rotation_y)
	preview_is_valid = placement_error.is_empty()
	_set_preview_color(preview_is_valid, placement_error)

func _get_machine_type() -> String:
	var item_tool := _tool_resource as ItemPlacementToolResource
	if item_tool != null:
		return item_tool.structure_type
	var binding := _tool_resource as HotbarBinding
	return binding.binding_id if binding != null and binding.kind == HotbarBinding.KIND_TOOL else _tool_resource.id

func _get_placeable_item_id() -> String:
	return ToolManager.get_placeable_item_id(_tool_resource)

func _set_preview_color(valid: bool, reason: String = "") -> void:
	var color := Color(0.3, 1.0, 0.4, 0.5) if valid else Color(1.0, 0.2, 0.2, 0.5)

	for material in _preview_materials:
		material.albedo_color = color

	UIManager.set_placement_status(
		"READY - click to place" if valid else reason,
		valid
	)

func _cleanup_preview() -> void:
	waiting_for_confirmation = false
	preview_is_valid = false
	_preview_materials.clear()
	
	if is_instance_valid(preview):
		preview.queue_free()
		preview = null
	
	UIManager.clear_placement_status()

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

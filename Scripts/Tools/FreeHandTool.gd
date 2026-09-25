## FreeHandTool.gd
## Single-step tool for free hand actions

extends "res://Scripts/Tools/BaseTool.gd"
class_name FreeHandTool

func on_execute(_p: Node) -> void:
	if player and player.has_method("get_player_transform") and player.has_method("get_direction"):
		var camera = player.get_node_or_null("Camera3D")
		var center = player.get_viewport().size / 2
		var from = camera.project_ray_origin(center)
		var to = from + camera.project_ray_normal(center) * 5
		var space_state = player.get_world_3d().direct_space_state
		
		var exclude = [player]
		
		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.collide_with_areas = true
		query.exclude = exclude
		var result = space_state.intersect_ray(query)
		
		if result and result.collider.get_parent().is_in_group("Petable"):
			result.collider.get_parent().pet()

		# other groups for "hand-actions"

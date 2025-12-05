## CollectTool.gd
## Single-step tool for collecting items

extends "res://Scripts/Tools/BaseTool.gd"

func on_execute(_p: Node) -> void:
	if player and player.has_method("get_player_transform"):
		scan_area()
	else:
		push_error("DestructTool: Player does not have get_origin method")

func scan_area():
	var query = PhysicsShapeQueryParameters3D.new()
	query.transform = player.get_player_transform()
	query.shape = SphereShape3D.new()
	query.shape.radius = 2.0
	
	var space = player.get_world_3d().direct_space_state
	var result = space.intersect_shape(query)
	for r in result:
		var obj = r.collider
		if (obj.is_in_group("Collectibles")):
			pick_up(obj.get_parent_node_3d())

func pick_up(item: Node3D):
	InventoryManager.add_item(item.dropData, 1)
	item.queue_free()

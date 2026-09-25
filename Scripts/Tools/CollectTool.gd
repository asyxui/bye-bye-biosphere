## CollectTool.gd
## Single-step tool for collecting items

extends "res://Scripts/Tools/BaseTool.gd"

func on_execute(_p: Node) -> void:
	if player and player.has_method("get_player_transform"):
		scan_area()
	else:
		push_error("CollectTool: Player does not have get_player_transform method")

func scan_area():
	var query = PhysicsShapeQueryParameters3D.new()
	query.transform = player.get_player_transform()
	query.collide_with_areas = true
	query.shape = SphereShape3D.new()
	query.shape.radius = 2.0
	
	var space = player.get_world_3d().direct_space_state
	var result = space.intersect_shape(query)
	var inventory: Inventory = InventoryManager.get_inventory()
	if inventory == null:
		return
	for r in result:
		var obj = r.collider
		if (obj.is_in_group("Collectibles")):
			pick_up(obj.get_parent_node_3d(), inventory)
	inventory.items_changed.emit()

func pick_up(item: Node3D, inventory: Inventory):
	if item == null or not item.has_method("get_item_stack"):
		return
	var source_stack: ItemStack = item.get_item_stack()
	if source_stack == null:
		return
	
	var inserted: int = inventory.insert_stack(source_stack)
	if inserted <= 0:
		return
	# Directly using the shared ItemStorage contract does not emit the
	# inventory-specific UI signal, so notify the inventory after a successful
	# partial transfer.
	
	if item.has_method("remove_quantity"):
		item.remove_quantity(inserted)
	else:
		item.queue_free()

## Inserts one recipe input from the player's inventory into a targeted smelter.
extends "res://Scripts/Tools/BaseTool.gd"

const RAY_LENGTH: float = 20.0

func on_execute(_p: Node) -> void:
	if player == null or not player.has_method("get_player_transform") or not player.has_method("get_direction"):
		return
	var origin: Vector3 = player.get_player_transform().origin
	var direction: Vector3 = player.get_direction()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * RAY_LENGTH)
	query.exclude = [player]
	var result: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return

	var target: Node = result.get("collider") as Node
	while target != null and not target.has_method("insert_from_inventory"):
		target = target.get_parent()
	if target == null:
		return

	var inserted: int = target.insert_from_inventory(1)
	if inserted > 0:
		UIManager.set_placement_status("Inserted %d item" % inserted, true)

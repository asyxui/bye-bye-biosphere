## DestructTool.gd
## Single-step tool for destroying blocks

extends "res://Scripts/Tools/BaseTool.gd"

func on_execute(_p: Node) -> void:
	if player and player.has_method("get_player_transform") and player.has_method("get_direction"):
		var origin: Vector3 = player.get_player_transform().origin
		var direction: Vector3 = player.get_direction()
		if MapManager.dismantle_structure(origin, direction):
			return
		MapManager._destroy(origin, direction)
	else:
		push_error("DestructTool: Player does not have get_player_transform or get_direction method")

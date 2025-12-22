## DestructTool.gd
## Single-step tool for destroying blocks

extends "res://Scripts/Tools/BaseTool.gd"

func on_execute(_p: Node) -> void:
	if player and player.has_method("get_player_transform") and player.has_method("get_direction"):
		MapManager._destroy(player.get_player_transform().origin, player.get_direction())
	else:
		push_error("DestructTool: Player does not have get_player_transform or get_direction method")

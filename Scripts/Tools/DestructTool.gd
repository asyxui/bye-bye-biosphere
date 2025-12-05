## DestructTool.gd
## Single-step tool for destroying blocks

extends "res://Scripts/Tools/BaseTool.gd"

func on_execute(_p: Node) -> void:
	if player and player.has_method("try_destroy"):
		player.try_destroy()
	else:
		push_error("DestructTool: Player does not have try_destroy method")

func is_multi_step() -> bool:
	return false

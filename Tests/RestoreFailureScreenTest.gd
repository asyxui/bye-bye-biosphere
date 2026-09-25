extends "res://Tests/TestCase.gd"

const RESTORE_FAILURE_SCREEN := preload("res://Scenes/UI/RestoreFailureScreen.tscn")

func _run() -> void:
	var screen := RESTORE_FAILURE_SCREEN.instantiate() as RestoreFailureScreen
	root.add_child(screen)
	screen.show_error(SaveManager.INCOMPATIBLE_SAVE_MESSAGE)
	check(screen.visible)
	check(screen.get_node("PanelContainer/MarginContainer/VBoxContainer/MessageLabel").text.contains("different prototype version"))

	var choose_world_requests := [0]
	screen.choose_world.connect(func(): choose_world_requests[0] += 1)
	var reset_world_requests := [0]
	screen.reset_world.connect(func(): reset_world_requests[0] += 1)
	screen.get_node("PanelContainer/MarginContainer/VBoxContainer/ChooseWorldButton").pressed.emit()
	screen.get_node("PanelContainer/MarginContainer/VBoxContainer/ResetWorldButton").pressed.emit()
	check(choose_world_requests[0] == 1)
	check(reset_world_requests[0] == 1)
	check(screen.get_node("PanelContainer/MarginContainer/VBoxContainer/ResetWorldButton").disabled)
	screen.show_error("Failed to load", false)
	check(not screen.get_node("PanelContainer/MarginContainer/VBoxContainer/ResetWorldButton").visible)
	screen.queue_free()

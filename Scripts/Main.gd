extends Node

var save_game_manager: Node


func _ready() -> void:
	CustomLogger.log_info("Starting Bye Bye Biosphere!")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	set_process_input(true)
	
	# Initialize save game manager
	if not save_game_manager:
		save_game_manager = load("res://Scripts/Managers/SaveGameManager.gd").new()
		add_child(save_game_manager)
		save_game_manager.save_completed.connect(_on_save_completed)
		set_meta("save_game_manager", save_game_manager)
	
	# Initialize game world state
	var state_restore_manager = get_node_or_null("/root/GameStateRestoreManager")
	if state_restore_manager:
		await state_restore_manager.initialize_startup_world()
	else:
		push_error("GameStateRestoreManager not found in autoloads")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_tool_wheel"):
		var hud = get_node_or_null("Hud")
		if hud:
			var tool_wheel = hud.get_node_or_null("ToolPickerWheel")
			if tool_wheel:
				var action_bar = hud.get_node_or_null("ActionBar")
				if action_bar:
					tool_wheel.open_wheel(action_bar.current_slot)
					get_viewport().set_input_as_handled()


## Handle save completion
func _on_save_completed(success: bool, error_message: String) -> void:
	if success:
		CustomLogger.log_info("Game saved successfully")
	else:
		push_error("Failed to save game: %s" % error_message)

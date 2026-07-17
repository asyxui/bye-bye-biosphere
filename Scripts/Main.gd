extends Node


func _ready() -> void:
	CustomLogger.log_info("Starting Bye Bye Biosphere!")
	
	# Connect to SaveManager signals
	SaveManager.save_completed.connect(_on_save_completed)
	
	# Initialize game world state
	var state_restore_manager = get_node_or_null("/root/GameStateRestoreManager")
	if state_restore_manager:
		if not await state_restore_manager.initialize_startup_world():
			CustomLogger.log_error("Startup world initialization failed")
	else:
		push_error("GameStateRestoreManager not found in autoloads")

## Handle save completion
func _on_save_completed(success: bool, error_message: String) -> void:
	if success:
		CustomLogger.log_info("Game saved successfully")
	else:
		push_error("Failed to save game: %s" % error_message)

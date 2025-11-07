extends Node


func _ready() -> void:
	CustomLogger.log_info("Starting Bye Bye Biosphere!")

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

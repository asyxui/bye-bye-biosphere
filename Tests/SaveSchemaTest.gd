## Headless checks for the strict prototype save boundary.
extends "res://Tests/TestCase.gd"

func _run() -> void:
	check(SaveManager.CURRENT_SAVE_VERSION == 1)
	check(SaveManager.validate_save_data({"game_metadata": {"version": 1}}))
	check(not SaveManager.validate_save_data({}))
	check(SaveManager.get_last_load_error() == SaveManager.INCOMPATIBLE_SAVE_MESSAGE)
	check(not SaveManager.validate_save_data({"game_metadata": {"version": 2}}))
	check(SaveManager.get_last_load_error() == SaveManager.INCOMPATIBLE_SAVE_MESSAGE)

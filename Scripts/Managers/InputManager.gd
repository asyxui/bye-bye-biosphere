extends Node

## Centralized input management system
## Provides mouse control and state checking without intercepting input events

signal mouse_mode_changed(new_mode: Input.MouseMode)

var mouse_capture_reason: String = ""  # Track why mouse is captured (e.g., "gameplay", "ui")

func _ready() -> void:
	# Initialize mouse as captured for gameplay
	mouse_capture_reason = "gameplay"

## Request mouse capture with a reason
func request_mouse_capture(reason: String) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	
	mouse_capture_reason = reason
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_mode_changed.emit(Input.MOUSE_MODE_CAPTURED)

## Request mouse release with a reason
func request_mouse_release(reason: String) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		return
	
	# Only release if it was captured for this reason
	if mouse_capture_reason == reason or reason == "":
		mouse_capture_reason = ""
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		mouse_mode_changed.emit(Input.MOUSE_MODE_VISIBLE)

## Check if mouse is captured
func is_mouse_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

## Convenience function to check if a specific system has input focus
func has_input_focus(system: String) -> bool:
	match system.to_lower():
		"console":
			return GameStateManager.is_console_open
		"menu":
			return GameStateManager.is_menu_open
		"gameplay":
			return not GameStateManager.is_modal_active()
		_:
			return false

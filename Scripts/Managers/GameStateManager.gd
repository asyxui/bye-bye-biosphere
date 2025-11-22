extends Node

## Global game state manager
## Tracks pause state, console state, menu state, and coordinates between systems

signal console_opened
signal console_closed
signal menu_opened
signal menu_closed

var is_paused: bool = false
var is_console_open: bool = false
var is_menu_open: bool = false

func _ready() -> void:
	set_process_input(true)

func _input(event: InputEvent) -> void:
	# Handle pause menu toggle
	if event.is_action_pressed("menu"):
		toggle_pause_menu()
		get_viewport().set_input_as_handled()
	# Handle debug console toggle with K
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		# Only open console with K when not already open
		if not is_console_open:
			open_console()
			get_viewport().set_input_as_handled()

## Toggle pause menu and game state
func toggle_pause_menu() -> void:
	if is_menu_open:
		close_menu()
	else:
		open_menu()

## Open pause menu
func open_menu() -> void:
	if is_menu_open:
		return
	
	is_menu_open = true
	is_paused = true
	get_tree().paused = true
	# Release mouse - use empty string to force release regardless of reason
	InputManager.request_mouse_release("")
	menu_opened.emit()

## Close pause menu
func close_menu() -> void:
	if not is_menu_open:
		return
	
	is_menu_open = false
	is_paused = false
	get_tree().paused = false
	
	# Only capture mouse if console is NOT open
	if not is_console_open:
		InputManager.request_mouse_capture("gameplay")
	
	menu_closed.emit()

## Toggle debug console
func toggle_console() -> void:
	if is_console_open:
		close_console()
	else:
		open_console()

## Open debug console
func open_console() -> void:
	if is_console_open:
		return
	
	is_console_open = true
	# Release mouse - use empty string to force release regardless of reason
	InputManager.request_mouse_release("")
	
	# Show console through HUDManager
	HUDManager.set_debug_console_visible(true)
	
	console_opened.emit()

## Close debug console
func close_console() -> void:
	if not is_console_open:
		return
	
	is_console_open = false
	
	# Hide console through HUDManager
	HUDManager.set_debug_console_visible(false)
	
	# Return to previous state (gameplay or menu)
	if is_menu_open:
		# Stay in menu, don't capture mouse
		pass
	else:
		InputManager.request_mouse_capture("gameplay")
	console_closed.emit()

## Check if any modal UI is active (blocks gameplay)
func is_modal_active() -> bool:
	return is_paused or is_console_open

## Get current game state as string (for debugging)
func get_state_summary() -> String:
	var states: Array[String] = []
	if is_paused:
		states.append("PAUSED")
	if is_console_open:
		states.append("CONSOLE_OPEN")
	if is_menu_open:
		states.append("MENU_OPEN")
	if states.is_empty():
		states.append("PLAYING")
	return ", ".join(states)

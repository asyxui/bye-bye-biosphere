extends Node

signal console_opened
signal console_closed
signal menu_opened
signal menu_closed
signal loading_changed(is_loading: bool, operation_name: String, progress: float)

var is_paused: bool = false
var is_console_open: bool = false
var is_menu_open: bool = false
var is_loading := false
var loading_operation := ""
var loading_progress := 0.0
var gravity_enabled: bool = true

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


func toggle_pause_menu() -> void:
	if is_menu_open:
		close_menu()
	else:
		open_menu()


func open_menu() -> void:
	if is_menu_open:
		return

	is_menu_open = true
	is_paused = true
	get_tree().paused = true
	# Release mouse - use empty string to force release regardless of reason
	InputManager.request_mouse_release("")
	menu_opened.emit()


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


func toggle_console() -> void:
	if is_console_open:
		close_console()
	else:
		open_console()


func open_console() -> void:
	if is_console_open:
		return

	is_console_open = true
	# Release mouse
	InputManager.request_mouse_release("")

	# Show console through HUDManager
	HUDManager.set_debug_console_visible(true)

	console_opened.emit()


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


func is_modal_active() -> bool:
	return is_paused or is_console_open or is_loading


func get_state_summary() -> String:
	var states: Array[String] = []
	if is_paused:
		states.append("PAUSED")
	if is_console_open:
		states.append("CONSOLE_OPEN")
	if is_menu_open:
		states.append("MENU_OPEN")
	if is_loading:
		states.append("LOADING")
	if states.is_empty():
		states.append("PLAYING")
	return ", ".join(states)


func start_loading(operation_name: String, first_checkpoint := "World stream configured") -> void:
	var was_loading = is_loading
	is_loading = true
	loading_operation = operation_name
	loading_progress = 0.0
	if not was_loading:
		PerformanceTracker.start_timer("Loading", first_checkpoint)
		gravity_enabled = false
		InputManager.request_mouse_release("")
	loading_changed.emit(is_loading, loading_operation, loading_progress)


func set_loading_progress(progress: float) -> void:
	var clamped_progress = clampf(progress, 0.0, 100.0)
	if is_equal_approx(loading_progress, clamped_progress):
		return
	loading_progress = clamped_progress
	loading_changed.emit(is_loading, loading_operation, loading_progress)


func finish_loading(success := true) -> void:
	var was_loading = is_loading
	loading_progress = 100.0
	is_loading = false
	var timer := PerformanceTracker.get_latest_timer("Loading")
	if timer.get("status", "") == "active":
		PerformanceTracker.stop_timer(timer.get("id", 0), success)
	gravity_enabled = true
	if was_loading:
		InputManager.request_mouse_capture("gameplay")
	loading_changed.emit(false, loading_operation, loading_progress)

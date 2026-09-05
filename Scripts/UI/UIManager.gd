extends Node

## The sole authority for UI navigation, mouse mode, pause state, and gameplay input.
signal screen_changed(screen_id: int)
signal context_changed(allows_gameplay: bool)

enum ScreenId { NONE, INVENTORY, CONSOLE, TOOL_WHEEL, PAUSE, SETTINGS, SAVE_LOAD, LOADING }
enum Channel { OVERLAY, MENU, DIALOG, SYSTEM }

const OVERLAY_SCREENS := [ScreenId.INVENTORY, ScreenId.CONSOLE, ScreenId.TOOL_WHEEL]
const MENU_SCREENS := [ScreenId.PAUSE, ScreenId.SETTINGS, ScreenId.SAVE_LOAD]

var _root: CanvasLayer
var _screens: Dictionary = {}
var _stack: Array[int] = []
var _focus_stack: Array[Control] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func register_root(root: CanvasLayer) -> void:
	_root = root
	_screens = root.get_screens()
	for screen in _screens.values():
		if screen is CanvasItem:
			screen.hide()
	GameStateManager.loading_changed.connect(_on_loading_changed)
	_apply_context()

func push(screen_id: ScreenId, data: Dictionary = {}) -> void:
	if screen_id == ScreenId.LOADING:
		_show_loading(data)
		return
	if not _screens.has(screen_id):
		push_error("UIManager: unregistered screen %s" % screen_id)
		return
	if is_open(screen_id):
		return
	if screen_id in OVERLAY_SCREENS:
		for open_id in OVERLAY_SCREENS:
			if open_id != screen_id and is_open(open_id):
				_remove(open_id)
	if screen_id in MENU_SCREENS and not _stack.is_empty() and _stack.back() in MENU_SCREENS:
		_screens[_stack.back()].hide()
	_store_focus()
	_stack.append(screen_id)
	_present(screen_id, data)
	_apply_context()

func replace(screen_id: ScreenId, data: Dictionary = {}) -> void:
	if not _stack.is_empty():
		_remove(_stack.back())
	push(screen_id, data)

func pop() -> void:
	if _stack.is_empty():
		return
	_remove(_stack.back())
	if not _stack.is_empty() and _stack.back() in MENU_SCREENS:
		_screens[_stack.back()].show()
		_focus_first(_screens[_stack.back()])
	_apply_context()
	_restore_focus()

func toggle(screen_id: ScreenId, data: Dictionary = {}) -> void:
	if is_open(screen_id):
		pop_screen(screen_id)
	else:
		push(screen_id, data)

func pop_screen(screen_id: ScreenId) -> void:
	if not is_open(screen_id):
		return
	_remove(screen_id)
	_apply_context()
	_restore_focus()

func is_open(screen_id: ScreenId) -> bool:
	return _stack.has(screen_id)

func allows_gameplay_input() -> bool:
	return _stack.is_empty() and not GameStateManager.is_loading

func set_placement_status(message: String, valid: bool) -> void:
	if _root == null:
		return
	var status: Control = _root.get_node_or_null("HUD/PlacementStatus") as Control
	if status == null:
		return
	var label: Label = status.get_node_or_null("Label") as Label
	if label != null:
		label.text = message
		label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5, 1.0) if valid else Color(1.0, 0.35, 0.3, 1.0))
	status.visible = not message.is_empty()

func clear_placement_status() -> void:
	set_placement_status("", false)

func set_interaction_status(message: String, valid: bool = true) -> void:
	if _root == null:
		return
	var status: Control = _root.get_node_or_null("HUD/InteractionStatus") as Control
	if status == null:
		return
	var label: Label = status.get_node_or_null("Label") as Label
	if label != null:
		label.text = message
		label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5, 1.0) if valid else Color(1.0, 0.35, 0.3, 1.0))
	status.visible = not message.is_empty()

func clear_interaction_status() -> void:
	set_interaction_status("", false)

## The middle-button press can be intercepted by HUD controls before it reaches
## _unhandled_input, so the global wheel trigger is observed here.
func _input(event: InputEvent) -> void:
	if not allows_gameplay_input():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
		push(ScreenId.TOOL_WHEEL, {"hotbar_slot": _root.get_action_bar().current_slot})
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if is_open(ScreenId.TOOL_WHEEL) and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
		pop_screen(ScreenId.TOOL_WHEEL)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		if GameStateManager.is_loading:
			return
		if not _stack.is_empty():
			pop()
		else:
			push(ScreenId.PAUSE)
		get_viewport().set_input_as_handled()
		return
	if not allows_gameplay_input():
		return
	if event.is_action_pressed("inventory"):
		toggle(ScreenId.INVENTORY)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		toggle(ScreenId.CONSOLE)
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("f3"):
		UIManager._root.get_node("HUD/F3Screen").toggle_label()

func _present(screen_id: ScreenId, data: Dictionary) -> void:
	var screen = _screens[screen_id]
	if screen_id == ScreenId.TOOL_WHEEL:
		screen.open_wheel(data.get("hotbar_slot", 0))
	elif screen_id == ScreenId.SAVE_LOAD:
		if data.get("save", false):
			screen.open_for_save()
		else:
			screen.open_for_load()
		screen.show()
	else:
		screen.show()
		_focus_first(screen)
	screen_changed.emit(screen_id)

func _remove(screen_id: ScreenId) -> void:
	var screen = _screens.get(screen_id)
	if screen_id == ScreenId.TOOL_WHEEL and screen:
		screen.close_wheel()
	elif screen:
		screen.hide()
	_stack.erase(screen_id)
	screen_changed.emit(_stack.back() if not _stack.is_empty() else ScreenId.NONE)

func _show_loading(data: Dictionary) -> void:
	var screen = _screens.get(ScreenId.LOADING)
	if screen:
		screen._on_loading_changed(true, data.get("operation", "Loading"), data.get("progress", 0.0))
	_apply_context()

func _on_loading_changed(active: bool, operation: String, progress: float) -> void:
	var screen = _screens.get(ScreenId.LOADING)
	if screen:
		screen._on_loading_changed(active, operation, progress)
	_apply_context()

func _apply_context() -> void:
	var gameplay := allows_gameplay_input()
	get_tree().paused = not gameplay and _has_menu_open()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if gameplay else Input.MOUSE_MODE_VISIBLE
	if gameplay:
		get_viewport().gui_release_focus()
	context_changed.emit(gameplay)

func _has_menu_open() -> bool:
	for screen_id in _stack:
		if screen_id in MENU_SCREENS:
			return true
	return false

func _store_focus() -> void:
	var focus := get_viewport().gui_get_focus_owner() as Control
	_focus_stack.append(focus if is_instance_valid(focus) else null)

func _restore_focus() -> void:
	if _focus_stack.is_empty():
		return
	var focus: Control = _focus_stack.pop_back()
	if is_instance_valid(focus) and focus.visible:
		focus.grab_focus()

func _focus_first(screen: Control) -> void:
	for child in screen.find_children("*", "Control", true, false):
		if child.focus_mode != Control.FOCUS_NONE and child.visible:
			child.grab_focus()
			return

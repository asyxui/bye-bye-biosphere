## HUDManager.gd
## Global manager for HUD and UI elements
extends Node

signal inventory_toggled(is_open: bool)
signal debug_console_toggled(is_open: bool)

func _ready() -> void:
	pass

## Get the inventory UI (find it fresh each time since scene reloads invalidate cached refs)
func _get_inventory_ui() -> Control:
	var hud = get_tree().current_scene.get_node_or_null("Hud")
	return hud.get_node_or_null("InventoryUI") if hud else null

## Get the debug console (find it fresh each time since scene reloads invalidate cached refs)
func _get_debug_console() -> Control:
	var hud = get_tree().current_scene.get_node_or_null("Hud")
	return hud.get_node_or_null("DebugConsole") if hud else null

## Toggle inventory UI visibility
func toggle_inventory() -> void:
	var inventory_ui = _get_inventory_ui()
	if inventory_ui:
		inventory_ui.visible = not inventory_ui.visible
		inventory_toggled.emit(inventory_ui.visible)
		
		# Handle mouse capture
		_handle_mouse_for_inventory(inventory_ui.visible)
		
		var inv_manager = get_node_or_null("/root/InventoryManager")
		if inv_manager:
			inv_manager.is_inventory_open = inventory_ui.visible
	else:
		push_error("HUDManager: Inventory UI not initialized")

## Set inventory visibility directly
func set_inventory_visible(visible: bool) -> void:
	var inventory_ui = _get_inventory_ui()
	if inventory_ui:
		inventory_ui.visible = visible
		inventory_toggled.emit(visible)

		print("inventory visible")
		
		# Handle mouse capture
		_handle_mouse_for_inventory(visible)
		
		var inv_manager = get_node_or_null("/root/InventoryManager")
		if inv_manager:
			inv_manager.is_inventory_open = visible
	else:
		push_error("HUDManager: Inventory UI not initialized")

## Handle mouse capture when opening/closing inventory
func _handle_mouse_for_inventory(is_open: bool) -> void:
	if is_open:
		# Release mouse when opening inventory for UI interaction
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		# Recapture mouse when closing inventory (if debug console isn't open)
		if not is_debug_console_open():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## Check if inventory is open
func is_inventory_open() -> bool:
	var inventory_ui = _get_inventory_ui()
	if inventory_ui:
		return inventory_ui.visible
	return false

## Get the inventory UI (for direct access if needed)
func get_inventory_ui() -> Control:
	return _get_inventory_ui()

## Set debug console visibility directly
func set_debug_console_visible(visible: bool) -> void:
	var debug_console = _get_debug_console()
	if debug_console:
		debug_console.visible = visible
		debug_console_toggled.emit(visible)
		_handle_mouse_for_debug_console(visible)
	else:
		push_error("HUDManager: Debug Console not initialized")

## Handle mouse capture when opening/closing debug console
func _handle_mouse_for_debug_console(is_open: bool) -> void:
	if is_open:
		# Release mouse when opening console for text input
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		# Recapture mouse when closing console (if inventory isn't open)
		if not is_inventory_open():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## Check if debug console is open
func is_debug_console_open() -> bool:
	var debug_console = _get_debug_console()
	if debug_console:
		return debug_console.visible
	return false

## Get the debug console (for direct access if needed)
func get_debug_console() -> Control:
	return _get_debug_console()

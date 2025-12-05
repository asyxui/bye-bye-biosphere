extends Control

# Signals for tool selection
signal tool_selected(tool_id: String, slot_index: int)

# Node references
var action_grid: GridContainer
var template_slot: PanelContainer
var current_slot: int = 0

const NUM_SLOTS = 10
const HOTKEYS = ["[1]", "[2]", "[3]", "[4]", "[5]", "[6]", "[7]", "[8]", "[9]", "[0]"]

func _ready():
	action_grid = $ActionGrid
	template_slot = action_grid.get_child(0)
	
	if not action_grid or not template_slot:
		CustomLogger.log_error("ActionBar: Failed to find grid or template slot")
		return
	
	# Generate dynamic slots from template
	_generate_slots()
	
	# Hide template
	template_slot.hide()
	
	# Set default selection
	select_tool(0)
	
	# Wait for ToolManager to be ready
	await get_tree().process_frame
	
	# Connect to ToolManager signals
	if ToolManager:
		ToolManager.tool_equipped.connect(_on_tool_equipped)
	
	# Set up input handling
	set_process_input(true)
	
	# Initial display
	_refresh_display()

func _generate_slots():
	# Create 10 slots by duplicating the template
	for i in range(NUM_SLOTS):
		var new_slot = template_slot.duplicate()
		action_grid.add_child(new_slot)
		new_slot.show()
		
		# Make slots clickable to select them
		var slot_index = i
		new_slot.gui_input.connect(func(event): _on_slot_clicked(event, slot_index))

func _refresh_display():
	# Update all slot displays based on ToolManager's hotbar
	for i in range(NUM_SLOTS):
		_update_slot_display(i)

func _update_slot_display(slot_index: int) -> void:
	# Get slot node (add 1 because template is at index 0)
	var slot_node = action_grid.get_child(slot_index + 1)
	if not slot_node:
		return
	
	var tool = ToolManager.get_tool_in_slot(slot_index)
	var vbox = slot_node.get_node_or_null("VBoxContainer")
	if vbox:
		var label = vbox.get_node_or_null("Label")
		var hotkey = vbox.get_node_or_null("Hotkey")
		var icon_rect = vbox.get_node_or_null("TextureRect")
		
		if tool:
			# Tool is equipped
			if label:
				label.text = tool.name
			if hotkey:
				hotkey.text = HOTKEYS[slot_index]
			if icon_rect and tool.icon:
				icon_rect.texture = tool.icon
		else:
			# Empty slot
			if label:
				label.text = "-"
			if hotkey:
				hotkey.text = HOTKEYS[slot_index]
			if icon_rect:
				icon_rect.texture = null

func select_tool(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= NUM_SLOTS:
		return
	
	current_slot = slot_index
	_highlight_selected_slot(slot_index)
	
	var tool = ToolManager.get_tool_in_slot(slot_index)
	if tool:
		tool_selected.emit(tool.id, slot_index)
	else:
		tool_selected.emit("", slot_index)

func _on_slot_clicked(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Just select this slot
		select_tool(slot_index)
		get_viewport().set_input_as_handled()

func _highlight_selected_slot(slot_index: int) -> void:
	if not action_grid:
		return
	
	# Remove highlight from all slots (skip template at index 0)
	for i in range(1, action_grid.get_child_count()):
		var slot_node = action_grid.get_child(i)
		if slot_node:
			var color_rect = slot_node.get_node_or_null("ColorRect")
			if color_rect:
				color_rect.color = Color(0.2, 0.2, 0.2, 1)
	
	# Highlight selected slot (add 1 because template is at index 0)
	var selected_slot = action_grid.get_child(slot_index + 1)
	if selected_slot:
		var selected_color_rect = selected_slot.get_node_or_null("ColorRect")
		if selected_color_rect:
			selected_color_rect.color = Color(0.4, 0.6, 0.2, 1)  # Green highlight

func _input(event: InputEvent) -> void:
	# Don't process input when menu is open
	if GameStateManager.is_menu_open:
		return
	
	# Check for scroll wheel to change selected slot
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			# Scroll up = previous slot
			var new_slot = (current_slot - 1) % NUM_SLOTS
			select_tool(new_slot)
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			# Scroll down = next slot
			var new_slot = (current_slot + 1) % NUM_SLOTS
			select_tool(new_slot)
			get_viewport().set_input_as_handled()
			return
	
	# Check for hotkey inputs 1-9 and 0
	for i in range(10):
		var action_name = "hotkey_" + str((i + 1) % 10)
		if event.is_action_pressed(action_name):
			select_tool(i)  # Just select, don't activate
			get_viewport().set_input_as_handled()
			break

func _on_tool_equipped(_tool_id: String, slot_index: int) -> void:
	_update_slot_display(slot_index)

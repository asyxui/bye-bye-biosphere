extends Control

# Signals for tool selection
signal tool_selected(tool_name: String, slot_index: int)

# Tool definition
class Tool:
	var tool_name: String
	var slot_index: int
	
	func _init(p_name: String, p_slot: int):
		tool_name = p_name
		slot_index = p_slot

# Action bar slots - stores tools
var action_slots: Array[Tool] = []
var current_tool: Tool = null

# Node references
var action_grid: GridContainer
var template_slot: PanelContainer

const NUM_SLOTS = 10
const HOTKEYS = ["[1]", "[2]", "[3]", "[4]", "[5]", "[6]", "[7]", "[8]", "[9]", "[0]"]

func _ready():
	action_grid = $ActionGrid
	template_slot = action_grid.get_child(0)
	
	if not action_grid or not template_slot:
		CustomLogger.log_error("ActionBar: Failed to find grid or template slot")
		return
	
	# Initialize action slots with tools
	_setup_tools()
	
	# Generate dynamic slots from template
	_generate_slots()
	
	# Hide template
	template_slot.hide()
	
	# Set default selection
	select_tool(0)
	
	# Set up input handling
	set_process_input(true)

func _setup_tools():
	# Slot 0: Conveyor Belt
	action_slots.push_back(Tool.new("Conveyor", 0))
	# Slot 1: Destruct
	action_slots.push_back(Tool.new("Destruct", 1))
	# Slots 2-9: Empty
	for i in range(2, NUM_SLOTS):
		action_slots.push_back(Tool.new("-", i))

func _generate_slots():
	# Create 10 slots by duplicating the template
	for i in range(NUM_SLOTS):
		var new_slot = template_slot.duplicate()
		action_grid.add_child(new_slot)
		new_slot.show()
		
		# Update the label and hotkey
		var vbox = new_slot.get_node_or_null("VBoxContainer")
		if vbox:
			var label = vbox.get_node_or_null("Label")
			var hotkey = vbox.get_node_or_null("Hotkey")
			
			if label:
				label.text = action_slots[i].tool_name
			if hotkey:
				hotkey.text = HOTKEYS[i]

func select_tool(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= action_slots.size():
		return
	
	current_tool = action_slots[slot_index]
	_highlight_selected_slot(slot_index)
	
	# Emit the signal with tool information
	tool_selected.emit(current_tool.tool_name, current_tool.slot_index)

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
	
	# Check for hotkey inputs 1-9 and 0
	for i in range(10):
		var action_name = "hotkey_" + str((i + 1) % 10)
		if event.is_action_pressed(action_name):
			select_tool(i)
			get_viewport().set_input_as_handled()
			break

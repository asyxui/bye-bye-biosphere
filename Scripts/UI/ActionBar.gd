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

	# Subscribe before any asynchronous startup work so save restoration and
	# tool-wheel equips cannot update ToolManager without updating the bar.
	ToolManager.tool_equipped.connect(_on_tool_equipped)
	InventoryManager.inventory.items_changed.connect(_on_inventory_changed)
	
	# Generate dynamic slots from template
	_generate_slots()
	
	# The template must not participate in GridContainer layout after cloning.
	template_slot.free()
	
	# Set default selection
	select_tool(0)
	
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
		new_slot.mouse_filter = Control.MOUSE_FILTER_STOP
		var contents := _get_slot_contents(new_slot)
		if contents != null:
			contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for child in contents.find_children("*", "Control", true, false):
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# Make slots clickable to select them
		var slot_index = i
		new_slot.gui_input.connect(func(event): _on_slot_clicked(event, slot_index))

func _refresh_display():
	# Update all slot displays based on ToolManager's hotbar
	for i in range(NUM_SLOTS):
		_update_slot_display(i)

func _update_slot_display(slot_index: int) -> void:
	var slot_node = action_grid.get_child(slot_index)
	if not slot_node:
		return
	
	var tool: ToolResource = ToolManager.get_tool_in_slot(slot_index) as ToolResource
	var vbox = _get_slot_contents(slot_node)
	if vbox:
		var label = vbox.get_node_or_null("Label")
		var quantity_label = vbox.get_node_or_null("QuantityLabel")
		var hotkey = vbox.get_node_or_null("Hotkey")
		var icon_rect = vbox.get_node_or_null("TextureRect")
		
		if tool:
			# Tool is equipped
			var binding := tool as HotbarBinding
			var display_name := _get_tool_display_name(tool, binding)
			var display_icon := _get_tool_display_icon(tool, binding)
			if label:
				label.visible = true
				if binding != null and binding.kind == HotbarBinding.KIND_ITEM:
					var item: InventoryItem = binding.item if binding.item != null else ItemUtils.item_object_by_id(binding.binding_id)
					var quantity: int = InventoryManager.get_inventory().get_extractable_quantity(binding.binding_id)
					label.text = item.name if item != null and not item.name.is_empty() else display_name
					if quantity_label:
						quantity_label.text = "x%d" % quantity
						quantity_label.visible = true
				else:
					label.text = display_name
					if quantity_label:
						quantity_label.text = ""
						quantity_label.visible = false
			if hotkey:
				hotkey.text = HOTKEYS[slot_index]
			if icon_rect:
				icon_rect.texture = display_icon
				icon_rect.visible = display_icon != null
				var icon_size: Vector2 = icon_rect.custom_minimum_size
				icon_size.y = 32.0 if display_icon != null else 0.0
				icon_rect.custom_minimum_size = icon_size
			slot_node.tooltip_text = "%s\n%s" % [display_name, _get_tool_description(tool, binding)]
		else:
			# Empty slot
			if label:
				label.text = ""
				label.visible = false
			if quantity_label:
				quantity_label.text = ""
				quantity_label.visible = false
			if hotkey:
				hotkey.text = HOTKEYS[slot_index]
			if icon_rect:
				icon_rect.texture = null
				icon_rect.visible = false
				var icon_size: Vector2 = icon_rect.custom_minimum_size
				icon_size.y = 0.0
				icon_rect.custom_minimum_size = icon_size
			slot_node.tooltip_text = ""

func _get_slot_contents(slot_node: Node) -> VBoxContainer:
	return slot_node.get_node_or_null("MarginContainer/VBoxContainer") as VBoxContainer

func _get_tool_display_name(tool: ToolResource, binding: HotbarBinding) -> String:
	if binding != null:
		return binding.get_display_name()
	var tool_name := str(tool.get("name"))
	return tool_name if not tool_name.is_empty() else str(tool.get("id"))

func _get_tool_display_icon(tool: ToolResource, binding: HotbarBinding) -> Texture2D:
	if binding != null:
		return binding.get_display_icon()
	return tool.icon

func _get_tool_description(tool: ToolResource, binding: HotbarBinding) -> String:
	if binding != null:
		return binding.get_display_description()
	return tool.description if not tool.description.is_empty() else "No description available."

func select_tool(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= NUM_SLOTS:
		return
	
	current_slot = slot_index
	_highlight_selected_slot(slot_index)
	
	var tool = ToolManager.get_tool_in_slot(slot_index)
	ToolManager.set_selected_hotbar_slot(slot_index, tool.id if tool else "")
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
	
	# Clear the visual state from every live slot.
	for i in range(action_grid.get_child_count()):
		var slot_panel := action_grid.get_child(i) as PanelContainer
		if slot_panel != null:
			slot_panel.theme_type_variation = UIThemeTypes.INVENTORY_SLOT
	
	var selected_panel := action_grid.get_child(slot_index) as PanelContainer
	if selected_panel != null:
		selected_panel.theme_type_variation = UIThemeTypes.INVENTORY_SLOT_SELECTED

func _unhandled_input(event: InputEvent) -> void:
	if not UIManager.allows_gameplay_input():
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

func _on_inventory_changed() -> void:
	_refresh_display()

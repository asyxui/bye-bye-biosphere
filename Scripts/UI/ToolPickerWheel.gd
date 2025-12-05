extends CanvasLayer
class_name ToolPickerWheel

# Visual properties
const WHEEL_RADIUS = 120.0
const ITEM_SIZE = 60.0

var is_open: bool = false
var wheel_container: Node2D
var tool_items: Array[Node] = []
var selected_hotbar_slot: int = -1  # Track which hotbar slot is being configured
var hovered_tool_index: int = -1

signal wheel_opened
signal wheel_closed

func _ready() -> void:
	# Wait for ToolManager to be ready
	await get_tree().process_frame
	
	# Create the wheel container
	wheel_container = Node2D.new()
	add_child(wheel_container)
	wheel_container.position = get_viewport().get_visible_rect().get_center()
	
	# Populate wheel with tools
	_populate_wheel()
	
	# Initially hidden
	hide()
	set_process_input(false)

func _populate_wheel() -> void:
	# ToolManager is an autoload, access directly
	var tool_manager = get_node("/root/ToolManager")
	if not tool_manager:
		push_error("ToolManager not available")
		return
	
	var all_tools = tool_manager.get_all_tools()
	if all_tools.is_empty():
		CustomLogger.log_info("No tools found to display in wheel")
		return
	
	var tool_array = all_tools.values()
	var num_tools = tool_array.size()
	var angle_step = TAU / num_tools
	
	for i in range(num_tools):
		var angle = i * angle_step - PI / 2  # Start from top
		var pos = Vector2(cos(angle), sin(angle)) * WHEEL_RADIUS
		
		var tool_item = _create_tool_item(tool_array[i], i, pos)
		wheel_container.add_child(tool_item)
		tool_items.append(tool_item)

func _create_tool_item(tool, index: int, position: Vector2) -> Control:
	# Create a large clickable area for the pie slice
	var container = Control.new()
	container.custom_minimum_size = Vector2(ITEM_SIZE * 2, ITEM_SIZE * 2)
	container.size = Vector2(ITEM_SIZE * 2, ITEM_SIZE * 2)
	container.position = position - Vector2(ITEM_SIZE, ITEM_SIZE)
	container.set_meta("tool_index", index)
	container.set_meta("tool_id", tool.id)
	container.mouse_entered.connect(func(): _on_tool_item_hover(index))
	container.mouse_exited.connect(func(): _on_tool_item_unhover())
	
	# Create panel background
	var bg = Panel.new()
	bg.size = Vector2(ITEM_SIZE * 2, ITEM_SIZE * 2)
	bg.modulate = Color(0.25, 0.25, 0.25, 0.8)
	container.add_child(bg)
	
	# VBox to center content vertically
	var vbox = VBoxContainer.new()
	vbox.size = Vector2(ITEM_SIZE * 2, ITEM_SIZE * 2)
	vbox.add_theme_constant_override("separation", 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(vbox)
	
	# Spacer to push content to center
	var spacer_top = Control.new()
	spacer_top.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer_top)
	
	# Tool icon (centered)
	var icon = TextureRect.new()
	icon.texture = tool.icon
	icon.custom_minimum_size = Vector2(ITEM_SIZE, ITEM_SIZE)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	var icon_container = HBoxContainer.new()
	icon_container.add_theme_constant_override("separation", 0)
	icon_container.alignment = BoxContainer.ALIGNMENT_CENTER
	icon_container.add_child(icon)
	vbox.add_child(icon_container)
	
	# Tool name label (centered)
	var name_label = Label.new()
	name_label.text = tool.name
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.custom_minimum_size = Vector2(ITEM_SIZE * 2 - 4, 0)
	vbox.add_child(name_label)
	
	return container

func _input(event: InputEvent) -> void:
	if not is_open:
		return
	
	# Close wheel on middle mouse release
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		if not event.pressed:
			close_wheel()
			get_viewport().set_input_as_handled()
	
	# Escape key also closes
	if event.is_action_pressed("ui_cancel"):
		close_wheel()
		get_viewport().set_input_as_handled()

func _on_tool_item_hover(index: int) -> void:
	hovered_tool_index = index
	
	# Highlight the hovered tool
	tool_items[index].modulate = Color(1.3, 1.3, 1.3, 1)
	
	# If a hotbar slot is selected, equip this tool to it
	if selected_hotbar_slot >= 0:
		var tool_item = tool_items[index]
		var tool_id = tool_item.get_meta("tool_id")
		var tool_manager = get_node("/root/ToolManager")
		
		if tool_manager.equip_tool(tool_id, selected_hotbar_slot):
			CustomLogger.log_info("Tool %s equipped to slot %d" % [tool_id, selected_hotbar_slot])

func _on_tool_item_unhover() -> void:
	if hovered_tool_index >= 0:
		# Restore normal color
		tool_items[hovered_tool_index].modulate = Color.WHITE
		hovered_tool_index = -1

func open_wheel(hotbar_slot: int) -> void:
	if is_open:
		return
	
	if hotbar_slot < 0 or hotbar_slot >= 10:
		push_error("Invalid hotbar slot: %d" % hotbar_slot)
		return
	
	selected_hotbar_slot = hotbar_slot
	is_open = true
	show()
	set_process_input(true)
	
	# Center on screen
	wheel_container.position = get_viewport().get_visible_rect().get_center()
	
	# Release mouse for UI interaction
	InputManager.request_mouse_release("gameplay")
	
	CustomLogger.log_info("Tool wheel opened for slot %d" % hotbar_slot)
	wheel_opened.emit()

func close_wheel() -> void:
	if not is_open:
		return
	
	is_open = false
	hide()
	set_process_input(false)
	
	# Reset hover state
	if hovered_tool_index >= 0:
		tool_items[hovered_tool_index].modulate = Color.WHITE
		hovered_tool_index = -1
	
	selected_hotbar_slot = -1
	
	# Recapture mouse for gameplay
	InputManager.request_mouse_capture("gameplay")
	
	wheel_closed.emit()

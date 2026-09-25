extends CanvasLayer
class_name ToolPickerWheel

# Visual properties
const MIN_WHEEL_RADIUS := 190.0
const MAX_WHEEL_RADIUS := 260.0
const ITEM_SIZE = 60.0

var is_open: bool = false
var wheel_container: Node2D
var tool_items: Array[Node] = []
var selected_hotbar_slot: int = -1  # Track which hotbar slot is being configured
var hovered_tool_index: int = -1

signal wheel_opened
signal wheel_closed

func _ready() -> void:
	# Create the wheel container
	wheel_container = Node2D.new()
	add_child(wheel_container)
	wheel_container.position = get_viewport().get_visible_rect().get_center()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# Populate wheel with tools
	_rebuild_wheel()
	GameStateManager.mode_changed.connect(_on_mode_changed)
	
	# Initially hidden
	hide()

func _populate_wheel() -> void:
	var all_tools = ToolManager.get_all_tools()
	if all_tools.is_empty():
		CustomLogger.log_info("No tools found to display in wheel")
		return
	
	var tool_array = all_tools.values()
	var num_tools = tool_array.size()
	var angle_step = TAU / num_tools
	var wheel_radius := _get_wheel_radius(num_tools)
	
	for i in range(num_tools):
		var angle = i * angle_step - PI / 2  # Start from top
		var pos = Vector2(cos(angle), sin(angle)) * wheel_radius
		
		var tool_item = _create_tool_item(tool_array[i], i, pos)
		wheel_container.add_child(tool_item)
		tool_items.append(tool_item)

func _on_mode_changed(_creative_enabled: bool) -> void:
	_rebuild_wheel()

func _on_viewport_size_changed() -> void:
	wheel_container.position = get_viewport().get_visible_rect().get_center()
	_rebuild_wheel()

func _rebuild_wheel() -> void:
	for child in wheel_container.get_children():
		child.queue_free()
	tool_items.clear()
	hovered_tool_index = -1
	_populate_wheel()

func _get_wheel_radius(tool_count: int) -> float:
	var viewport_size := get_viewport().get_visible_rect().size
	var responsive_radius := minf(viewport_size.x, viewport_size.y) * 0.33
	var spacing_radius := (ITEM_SIZE * 2.0) / (2.0 * sin(PI / float(maxi(1, tool_count)))) if tool_count > 1 else 0.0
	return clampf(maxf(MIN_WHEEL_RADIUS, maxf(spacing_radius, responsive_radius)), MIN_WHEEL_RADIUS, MAX_WHEEL_RADIUS)

func _create_tool_item(tool: Resource, index: int, position: Vector2) -> Control:
	# Create a large clickable area for the pie slice
	var container = Control.new()
	container.custom_minimum_size = Vector2(ITEM_SIZE * 2, ITEM_SIZE * 2)
	container.size = Vector2(ITEM_SIZE * 2, ITEM_SIZE * 2)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.position = position - Vector2(ITEM_SIZE, ITEM_SIZE)
	container.set_meta("tool_index", index)
	container.set_meta("tool_entry", tool)
	container.mouse_entered.connect(func(): _on_tool_item_hover(index))
	container.mouse_exited.connect(func(): _on_tool_item_unhover())
	container.gui_input.connect(func(event): _on_tool_item_input(event, index))
	
	# Theme supplies the component state styling for generated wheel items.
	var bg = Panel.new()
	bg.size = Vector2(ITEM_SIZE * 2, ITEM_SIZE * 2)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.theme_type_variation = &"ToolWheelItem"
	container.add_child(bg)
	
	# VBox to center content vertically
	var vbox = VBoxContainer.new()
	vbox.size = Vector2(ITEM_SIZE * 2, ITEM_SIZE * 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(vbox)
	
	# Spacer to push content to center
	var spacer_top = Control.new()
	spacer_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer_top.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer_top)
	
	# Tool icon (centered)
	var icon = TextureRect.new()
	var display_icon := _get_tool_display_icon(tool)
	icon.texture = display_icon
	icon.visible = display_icon != null
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(ITEM_SIZE, 42.0 if display_icon != null else 4.0)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	var icon_container = HBoxContainer.new()
	icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_container.add_theme_constant_override("separation", 0)
	icon_container.alignment = BoxContainer.ALIGNMENT_CENTER
	icon_container.add_child(icon)
	vbox.add_child(icon_container)
	
	# Tool name label (centered)
	var name_label = Label.new()
	name_label.text = _get_tool_display_name(tool)
	name_label.add_theme_font_size_override("font_size", 13 if display_icon == null else 11)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.max_lines_visible = 2
	name_label.custom_minimum_size = Vector2(ITEM_SIZE * 2 - 4, 30)
	name_label.tooltip_text = "%s\n%s" % [_get_tool_display_name(tool), _get_tool_description(tool)]
	vbox.add_child(name_label)
	
	return container

func _on_tool_item_hover(index: int) -> void:
	hovered_tool_index = index
	
	# Highlight the hovered tool
	tool_items[index].modulate = Color(1.3, 1.3, 1.3, 1)
	
	_equip_tool_item(index)

func _on_tool_item_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_equip_tool_item(index)
		get_viewport().set_input_as_handled()

func _equip_tool_item(index: int) -> void:
	# If a hotbar slot is selected, equip this tool to it.
	if selected_hotbar_slot >= 0:
		var tool_item = tool_items[index]
		var tool_entry: Resource = tool_item.get_meta("tool_entry") as Resource
		var tool_manager = get_node("/root/ToolManager")
		
		if tool_manager.equip_wheel_entry(tool_entry, selected_hotbar_slot):
			CustomLogger.log_info("Wheel entry equipped to slot %d" % selected_hotbar_slot)

func _get_tool_display_name(tool: Resource) -> String:
	var binding := tool as HotbarBinding
	if binding != null:
		return binding.get_display_name()
	var tool_name := str(tool.get("name"))
	return tool_name if not tool_name.is_empty() else str(tool.get("id"))

func _get_tool_display_icon(tool: Resource) -> Texture2D:
	var binding := tool as HotbarBinding
	if binding != null:
		return binding.get_display_icon()
	return tool.get("icon") as Texture2D

func _get_tool_description(tool: Resource) -> String:
	var binding := tool as HotbarBinding
	if binding != null:
		return binding.get_display_description()
	var description := str(tool.get("description"))
	return description if not description.is_empty() else "No description available."

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
	
	# Center on screen
	wheel_container.position = get_viewport().get_visible_rect().get_center()
	
	CustomLogger.log_info("Tool wheel opened for slot %d" % hotbar_slot)
	wheel_opened.emit()

func close_wheel() -> void:
	if not is_open:
		return
	
	is_open = false
	hide()
	
	# Reset hover state
	if hovered_tool_index >= 0:
		tool_items[hovered_tool_index].modulate = Color.WHITE
		hovered_tool_index = -1
	
	selected_hotbar_slot = -1
	
	wheel_closed.emit()

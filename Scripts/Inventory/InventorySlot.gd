## InventorySlot.gd
## UI component for a single inventory slot
extends PanelContainer

signal slot_selected(slot_index: int)
signal item_dropped(slot_index: int)
signal slot_drag_started(slot_index: int)
signal slot_drag_ended(from_slot: int, to_slot: int)
signal split_requested(slot_index: int)
signal combine_requested(slot_index: int)
signal item_equipped(slot_index: int)

@onready var icon_rect = $MarginContainer/VBoxContainer/IconRect
@onready var quantity_label = $MarginContainer/VBoxContainer/TopBar/QuantityLabel
@onready var name_label = $MarginContainer/VBoxContainer/NameLabel

var slot_index: int = -1
var current_stack = null  # InventoryStack type
var is_selected: bool = false

# Static variable to track drag state globally
static var dragging_from_index: int = -1
static var all_slots: Array = []

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	clear_slot()
	# Register this slot in the global list
	all_slots.append(self)

## Set up the slot with an inventory stack
func set_stack(stack, index: int) -> void:
	slot_index = index
	current_stack = stack
	
	if stack == null or stack.is_empty() or stack.item == null:
		clear_slot()
		return
	
	icon_rect.texture = stack.item.icon
	quantity_label.text = str(stack.quantity) if stack.quantity > 1 else ""
	name_label.text = stack.item.name
	name_label.add_theme_color_override("font_color", stack.item.get_rarity_color())

## Clear the slot display
func clear_slot() -> void:
	icon_rect.texture = null
	quantity_label.text = ""
	name_label.text = "Empty"
	name_label.add_theme_color_override("font_color", Color.GRAY)
	current_stack = null

## Select this slot
func select() -> void:
	is_selected = true
	# Create a new stylebox for selected state with exact same border as default
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.2, 0.6, 1, 0.3)
	stylebox.border_width_left = 2
	stylebox.border_width_top = 2
	stylebox.border_width_right = 2
	stylebox.border_width_bottom = 2
	stylebox.border_color = Color(0.4, 0.8, 1, 1)
	stylebox.set_corner_radius_all(3)
	stylebox.content_margin_left = 0
	stylebox.content_margin_top = 0
	stylebox.content_margin_right = 0
	stylebox.content_margin_bottom = 0
	add_theme_stylebox_override("panel", stylebox)

## Deselect this slot
func deselect() -> void:
	is_selected = false
	# Remove the override to use the default theme
	remove_theme_stylebox_override("panel")

## Get tooltip text
func get_slot_tooltip() -> String:
	if current_stack == null or current_stack.item == null:
		return "Empty Slot"
	
	var item = current_stack.item
	var text = item.name + "\n"
	text += "Quantity: " + str(current_stack.quantity) + "\n"
	text += item.description + "\n"
	text += "Weight: " + str(item.weight) + " kg"
	
	return text

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				slot_selected.emit(slot_index)
				dragging_from_index = slot_index
				slot_drag_started.emit(slot_index)
				get_tree().root.set_input_as_handled()
			else:
				if dragging_from_index != -1:
					# Find which slot the mouse is actually over
					var target_slot = _find_slot_under_mouse()
					slot_drag_ended.emit(dragging_from_index, target_slot)
					dragging_from_index = -1
					get_tree().root.set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_show_context_menu()
			get_tree().root.set_input_as_handled()

## Find which slot the mouse is currently over
func _find_slot_under_mouse() -> int:
	var mouse_pos = get_global_mouse_position()
	for slot in all_slots:
		if slot.get_global_rect().has_point(mouse_pos):
			return slot.slot_index
	return dragging_from_index  # Return source if no slot found

func _on_mouse_entered() -> void:
	if dragging_from_index != -1 and current_stack and not current_stack.is_empty():
		show_drag_target()

func _on_mouse_exited() -> void:
	# Don't reset while dragging - let other slots handle the highlight
	pass

## Show visual feedback for drag preview
func show_drag_preview() -> void:
	modulate = Color(1.2, 1.2, 1.2, 1.0)

## Show visual feedback for drag target
func show_drag_target() -> void:
	var stylebox = load("res://Resources/Inventory/InventorySlotSelected.tres")
	if stylebox:
		add_theme_stylebox_override("panel", stylebox)

## Show context menu for item operations
func _show_context_menu() -> void:
	if current_stack == null or current_stack.is_empty():
		return
	
	var menu = PopupMenu.new()
	add_child(menu)
	
	# Always show split option if quantity > 1
	if current_stack.quantity > 1:
		menu.add_item("Split Stack", 0)
	
	# Always show combine option
	menu.add_item("Combine All", 1)
	
	# Always show drop option
	menu.add_item("Drop Item", 2)

	# Always show drop option
	menu.add_item("Equip Item", 3)
	
	var menu_handler = func(id):
		match id:
			0:  # Split
				split_requested.emit(slot_index)
			1:  # Combine
				combine_requested.emit(slot_index)
			2:  # Drop
				item_dropped.emit(slot_index)
			3:  # Equip
				item_equipped.emit(slot_index)
		menu.queue_free()
	
	menu.id_pressed.connect(menu_handler)
	var mouse_pos = get_global_mouse_position()
	menu.position = mouse_pos
	menu.popup_on_parent(Rect2(mouse_pos, Vector2.ZERO))

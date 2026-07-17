## InventoryUI.gd
## UI controller for the inventory display
extends Control

@onready var grid_container = $Panel/MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var weight_label = $Panel/MarginContainer/VBoxContainer/StatsContainer/WeightLabel
@onready var slots_label = $Panel/MarginContainer/VBoxContainer/StatsContainer/SlotsLabel
@onready var close_button = $Panel/MarginContainer/VBoxContainer/TitleBar/CloseButton

var inventory = null  # Inventory type
var slot_scenes: Array = []
var selected_slot_index: int = -1
var dragging_from_slot: int = -1
var inventory_interactions = null

func _ready() -> void:
	var manager = get_node_or_null("/root/InventoryManager")
	if manager == null:
		push_error("InventoryManager autoload not found!")
		return
	
	inventory = manager.get_inventory()
	inventory.items_changed.connect(_on_inventory_changed)
	
	# Get or create InventoryInteractions
	inventory_interactions = get_node_or_null("/root/InventoryInteractions")
	if inventory_interactions == null:
		# Create it if it doesn't exist - defer to avoid "parent node is busy" error
		call_deferred("_setup_inventory_interactions")
	
	close_button.pressed.connect(_on_close_pressed)
	
	_initialize_slots()
	_refresh_display()

## Setup InventoryInteractions node (deferred)
func _setup_inventory_interactions() -> void:
	if get_node_or_null("/root/InventoryInteractions") == null:
		var interactions = Node.new()
		interactions.name = "InventoryInteractions"
		interactions.set_script(load("res://Scripts/Inventory/InventoryInteractions.gd"))
		get_tree().root.add_child(interactions)
		inventory_interactions = interactions

## Create slot UI elements
func _initialize_slots() -> void:
	for i in range(inventory.inventory_size):
		var slot_scene = preload("res://Scenes/Inventory/InventorySlot.tscn").instantiate()
		grid_container.add_child(slot_scene)
		slot_scenes.append(slot_scene)
		
		slot_scene.slot_selected.connect(_on_slot_selected)
		slot_scene.item_dropped.connect(_on_slot_dropped)
		slot_scene.item_equipped.connect(_on_slot_equipped)
		slot_scene.slot_drag_started.connect(_on_slot_drag_started)
		slot_scene.slot_drag_ended.connect(_on_slot_drag_ended)
		slot_scene.split_requested.connect(_on_split_requested)
		slot_scene.combine_requested.connect(_on_combine_requested)

## Refresh inventory display
func _refresh_display() -> void:
	for i in range(slot_scenes.size()):
		var slot_ui = slot_scenes[i]
		var stack = inventory.get_slot_item(i)
		slot_ui.set_stack(stack, i)
		
		if i == selected_slot_index:
			slot_ui.select()
		else:
			slot_ui.deselect()
	
	# Update stats
	var weight = inventory.get_total_weight()
	var weight_percent = (weight / inventory.max_weight) * 100
	weight_label.text = "Weight: %.1f / %.1f kg (%.0f%%)" % [weight, inventory.max_weight, weight_percent]
	slots_label.text = "Slots: %d / %d" % [inventory.inventory_size - inventory.get_empty_slots(), inventory.inventory_size]

## Handle slot selection
func _on_slot_selected(slot_index: int) -> void:
	var old_selection = selected_slot_index
	selected_slot_index = slot_index
	
	if old_selection != -1 and old_selection < slot_scenes.size():
		slot_scenes[old_selection].deselect()
	
	if slot_index < slot_scenes.size():
		slot_scenes[slot_index].select()
	
	_show_slot_info(slot_index)

## Handle slot right-click (drop item)
func _on_slot_dropped(slot_index: int) -> void:
	var stack = inventory.get_slot_item(slot_index)
	if stack and not stack.is_empty():
		inventory.remove_item(stack.item, stack.quantity)

## Handle slot right click (equip item)
func _on_slot_equipped(slot_index: int): 
	var hud = get_node_or_null("/root/Node3D/Hud")
	if hud:
		var action_bar = hud.get_node_or_null("ActionBar")
		var current_slot = action_bar.current_slot
		if ToolManager.equip_item(slot_index, current_slot):
			CustomLogger.log_info("Item from slot %s equipped to slot %d" % [slot_index, current_slot])

## Show item info for selected slot
func _on_slot_info_updated() -> void:
	_refresh_display()

## Show detailed info about slot contents
func _show_slot_info(_slot_index: int) -> void:
	# Can be used for displaying item info in the future
	pass

## Close inventory
func _on_close_pressed() -> void:
	var hud_mgr = get_node_or_null("/root/HUDManager")
	if hud_mgr:
		hud_mgr.toggle_inventory()
	else:
		hide()

## Refresh when inventory changes
func _on_inventory_changed() -> void:
	_refresh_display()

## Handle drag start
func _on_slot_drag_started(slot_index: int) -> void:
	dragging_from_slot = slot_index
	if slot_index < slot_scenes.size():
		slot_scenes[slot_index].show_drag_preview()

## Handle drag end (drop to another slot)
func _on_slot_drag_ended(from_slot: int, to_slot: int) -> void:
	if from_slot < 0 or from_slot >= slot_scenes.size():
		_clear_all_drag_visuals()
		return
	
	# Reset visual on the source slot
	if from_slot < slot_scenes.size():
		slot_scenes[from_slot].modulate = Color.WHITE
		slot_scenes[from_slot].remove_theme_stylebox_override("panel")
	
	var from_stack = inventory.get_slot_item(from_slot)
	if from_stack == null or from_stack.is_empty():
		_clear_all_drag_visuals()
		return
	
	# Only perform the move if we're dropping on a different slot
	if to_slot != from_slot and to_slot >= 0 and to_slot < inventory.inventory_size:
		if inventory_interactions != null:
			inventory_interactions.move_item(from_slot, to_slot)
	
	_clear_all_drag_visuals()

## Clear all drag visual feedback
func _clear_all_drag_visuals() -> void:
	for slot in slot_scenes:
		slot.modulate = Color.WHITE
		slot.remove_theme_stylebox_override("panel")

## Handle split request - show split UI
func _on_split_requested(slot_index: int) -> void:
	var stack = inventory.get_slot_item(slot_index)
	if stack == null or stack.is_empty() or stack.quantity <= 1:
		return
	
	_show_split_dialog(slot_index, stack)

## Handle combine request
func _on_combine_requested(slot_index: int) -> void:
	var stack = inventory.get_slot_item(slot_index)
	if stack == null or stack.item == null:
		return
	
	inventory_interactions.combine_item_type(stack.item)

## Show split dialog
func _show_split_dialog(slot_index: int, stack) -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = "Split Stack"
	
	var vbox = VBoxContainer.new()
	var label = Label.new()
	label.text = "How many items to split?\nCurrent: %d" % stack.quantity
	vbox.add_child(label)
	
	var spinner = SpinBox.new()
	spinner.min_value = 1
	spinner.max_value = stack.quantity - 1
	spinner.value = stack.quantity / 2
	vbox.add_child(spinner)
	
	dialog.add_child(vbox)
	
	dialog.confirmed.connect(func():
		# Find empty slot or slot with same item
		var target_slot = _find_target_slot_for_split(slot_index)
		if target_slot != -1:
			inventory_interactions.split_item(slot_index, target_slot, int(spinner.value))
		dialog.queue_free()
	)
	
	dialog.canceled.connect(func(): dialog.queue_free())
	get_tree().root.add_child(dialog)
	dialog.popup_centered_ratio(0.3)

## Find a suitable target slot for splitting
func _find_target_slot_for_split(from_slot: int) -> int:
	var from_stack = inventory.get_slot_item(from_slot)
	
	# First try to find empty slots
	for i in range(inventory.inventory_size):
		if i != from_slot and inventory.get_slot_item(i).is_empty():
			return i
	
	# Then try slots with the same item
	for i in range(inventory.inventory_size):
		var slot = inventory.get_slot_item(i)
		if i != from_slot and slot.item == from_stack.item:
			return i
	
	return -1

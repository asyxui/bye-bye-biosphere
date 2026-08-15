## InventoryUI.gd
## UI controller for the inventory display
extends UIScreen

@onready var grid_container = $Panel/MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var weight_label = $Panel/MarginContainer/VBoxContainer/StatsContainer/WeightLabel
@onready var slots_label = $Panel/MarginContainer/VBoxContainer/StatsContainer/SlotsLabel
@onready var close_button = $Panel/MarginContainer/VBoxContainer/TitleBar/CloseButton
@onready var recipe_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/CraftingSection/RecipeScroll/RecipeList

var inventory = null  # Inventory type
var slot_scenes: Array = []
var crafting_recipes: Array[Recipe] = []
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
	GameStateManager.mode_changed.connect(_on_mode_changed)
	crafting_recipes = Handcrafting.get_recipes()
	
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
	_refresh_crafting()

func _refresh_crafting() -> void:
	for child in recipe_list.get_children():
		recipe_list.remove_child(child)
		child.queue_free()

	for recipe in crafting_recipes:
		recipe_list.add_child(_create_recipe_row(recipe))

func _create_recipe_row(recipe: Recipe) -> Control:
	var row := VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 2)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = recipe.get_display_name()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 15)
	header.add_child(title)
	var output_item: InventoryItem = ItemUtils.item_object_by_id(recipe.output_item_id)
	var output_label := Label.new()
	output_label.text = "Produces: %d %s" % [recipe.output_quantity, output_item.name if output_item != null else recipe.output_item_id]
	output_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(output_label)
	var craft_button := Button.new()
	craft_button.text = "Craft"
	craft_button.custom_minimum_size = Vector2(80, 30)
	craft_button.pressed.connect(_on_craft_pressed.bind(recipe))
	header.add_child(craft_button)
	row.add_child(header)

	var requirements := Label.new()
	requirements.text = _format_recipe_requirements(recipe)
	requirements.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(requirements)

	var status := Label.new()
	status.text = _get_recipe_status(recipe)
	status.theme_type_variation = UIThemeTypes.STATUS_MUTED
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(status)

	craft_button.disabled = not Handcrafting.can_craft(recipe, inventory)
	craft_button.tooltip_text = status.text
	return row

func _format_recipe_requirements(recipe: Recipe) -> String:
	var requirements: Array[String] = []
	var recipe_requirements: Dictionary = recipe.get_input_requirements()
	for item_key in recipe_requirements:
		var item_id: String = str(item_key)
		var required: int = int(recipe_requirements[item_key])
		var owned: int = inventory.get_extractable_quantity(item_id)
		var item: InventoryItem = ItemUtils.item_object_by_id(item_id)
		var item_name: String = item.name if item != null else item_id
		requirements.append("%s: %d / %d" % [item_name, owned, required])
	return "Required: " + ", ".join(requirements)

func _get_recipe_status(recipe: Recipe) -> String:
	var output_item: InventoryItem = ItemUtils.item_object_by_id(recipe.output_item_id)
	if output_item == null:
		return "Unavailable: output item is missing."
	var output_stack: ItemStack = ItemStack.new(output_item, recipe.output_quantity)
	if inventory.get_insertable_quantity(output_stack, recipe.output_quantity) < recipe.output_quantity:
		return "Cannot craft: inventory has no room for the output."
	var missing: Dictionary = Handcrafting.get_missing(recipe, inventory)
	if not missing.is_empty():
		return ConstructionCosts.format_missing(missing)
	if not GameStateManager.construction_costs_enabled():
		return "Creative mode: ingredients not required."
	return "Ready to craft."

func _on_craft_pressed(recipe: Recipe) -> void:
	Handcrafting.craft(recipe, inventory)

func _on_mode_changed(_creative_enabled: bool) -> void:
	_refresh_display()

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
	var action_bar = UIManager._root.get_action_bar()
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
	UIManager.pop_screen(UIManager.ScreenId.INVENTORY)

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
		if i != from_slot and slot.is_same_item(from_stack):
			return i
	
	return -1

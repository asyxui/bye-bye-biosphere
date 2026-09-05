extends Node

var tools: Dictionary = {} # tool_id -> ToolResource
var tool_executor: Node
var hotbar_tools: Array[Resource] = [] # HotbarBinding or null for each slot (size 10)
var active_tool_instance: Object = null # Cache the active tool instance so state persists
var selected_hotbar_slot: int = -1

signal tool_equipped(tool_id: String, slot_index: int)
signal tool_activated(tool_id: String, slot_index: int)
signal active_tool_invalidated(new_tool_id: String)

const HOTBAR_SIZE = 10
const TOOLS_PATH = "res://Resources/Tools"

func _ready() -> void:
	# Initialize hotbar with empty slots
	hotbar_tools.resize(HOTBAR_SIZE)
	for i in range(HOTBAR_SIZE):
		hotbar_tools[i] = null

	# Create tool executor
	tool_executor = ToolExecutor.new()
	add_child(tool_executor)

	# Discover and load all tools from Resources/Tools/
	_load_tools()
	GameStateManager.mode_changed.connect(_on_mode_changed)
	InventoryManager.inventory.items_changed.connect(_on_inventory_changed)

	# Register as saveable
	add_to_group("saveable")

func _on_inventory_changed() -> void:
	for slot_index in range(hotbar_tools.size()):
		var binding := hotbar_tools[slot_index] as HotbarBinding
		if binding == null or binding.kind != HotbarBinding.KIND_ITEM:
			continue
		if binding.item is PlaceableItem and not GameStateManager.is_creative_mode() \
			and InventoryManager.get_inventory().get_extractable_quantity(binding.binding_id) <= 0:
			_cancel_placeable_binding_if_empty(binding, slot_index)

func _load_tools() -> void:
	for file_name in ResourceLoader.list_directory(TOOLS_PATH):
		if not file_name.ends_with(".tres"):
			continue
		var tool = load(TOOLS_PATH.path_join(file_name))
		if tool is ToolResource and not tool.id.is_empty():
			tools[tool.id] = tool
			print("Loaded tool: %s from %s" % [tool.id, file_name])

func get_tool(tool_id: String):
	return tools.get(tool_id)

func get_all_tools() -> Dictionary:
	var available_tools: Dictionary = {}
	for tool_id in tools:
		var tool: ToolResource = tools[tool_id] as ToolResource
		# Legacy structure tools are replaced by virtual item bindings in
		# creative mode; keep the development-only producer entry available.
		if is_tool_available(tool_id) and (not tool.structure_placement_tool or tool.creative_only):
			available_tools[tool_id] = tool
	if GameStateManager.is_creative_mode():
		for item in ItemUtils.get_all_items():
			if item is PlaceableItem:
				var binding := _create_placeable_binding(item as PlaceableItem)
				available_tools[binding.id] = binding
	return available_tools

func is_tool_available(tool_id: String) -> bool:
	var tool: ToolResource = get_tool(tool_id) as ToolResource
	return tool != null \
		and (not tool.creative_only or GameStateManager.is_creative_mode()) \
		and (not tool.structure_placement_tool or GameStateManager.is_creative_mode())

func _create_tool_binding(tool: ToolResource) -> HotbarBinding:
	var binding := HotbarBinding.new()
	binding.configure_tool(tool )
	return binding

func equip_tool(tool_id: String, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= HOTBAR_SIZE:
		push_error("Invalid slot index: %d" % slot_index)
		return false

	var tool = get_tool(tool_id)
	if not tool:
		push_error("Tool not found: %s" % tool_id)
		return false
	if not is_tool_available(tool_id):
		push_error("Tool unavailable in normal mode: %s" % tool_id)
		return false

	var binding := _create_tool_binding(tool as ToolResource)
	hotbar_tools[slot_index] = binding
	_invalidate_active_tool_if_needed(binding.id, slot_index)
	tool_equipped.emit(binding.id, slot_index)
	return true

func equip_item(inventory_slot_id: int, slot_index: int):
	if slot_index < 0 or slot_index >= HOTBAR_SIZE:
		push_error("Invalid slot index: %d" % slot_index)
		return false

	if inventory_slot_id < 0 or inventory_slot_id >= InventoryManager.inventory.inventory_size:
		push_error("Invalid inventory index: %d" % slot_index)
		return false

	var stack = InventoryManager.inventory.get_slot_item(inventory_slot_id)
	if stack == null or stack.is_empty() or stack.item == null:
		return false
	var item = stack.item
	return _equip_item_definition(item as InventoryItem, slot_index)

func _equip_item_definition(item: InventoryItem, slot_index: int) -> bool:
	if item == null or slot_index < 0 or slot_index >= HOTBAR_SIZE:
		return false
	if item is PlaceableItem:
		return equip_placeable_item(item as PlaceableItem, slot_index)

	var binding := HotbarBinding.new()
	binding.configure_item(item)
	hotbar_tools[slot_index] = binding
	_invalidate_active_tool_if_needed(binding.id, slot_index)
	tool_equipped.emit(binding.id, slot_index)
	return true

func equip_placeable_item(item: PlaceableItem, slot_index: int) -> bool:
	if item == null or slot_index < 0 or slot_index >= HOTBAR_SIZE:
		return false
	if not GameStateManager.is_creative_mode() and InventoryManager.get_inventory().get_extractable_quantity(str(item.id)) <= 0:
		return false
	var item_tool := _create_placeable_binding(item)
	hotbar_tools[slot_index] = item_tool
	_invalidate_active_tool_if_needed(item_tool.id, slot_index)
	tool_equipped.emit(item_tool.id, slot_index)
	return true

func _create_placeable_binding(item: PlaceableItem) -> ItemPlacementToolResource:
	var item_tool := ItemPlacementToolResource.new()
	item_tool.configure_item(item)
	item_tool.name = item.name
	item_tool.description = item.get_placement_description()
	item_tool.icon = item.get_placement_icon()
	item_tool.binding_id = str(item.id)
	item_tool.id = "%s:%s" % [HotbarBinding.KIND_ITEM, item_tool.binding_id]
	item_tool.item = item
	item_tool.item_id = item_tool.binding_id
	item_tool.structure_type = item.structure_type
	item_tool.placement_category = item.placement_category
	item_tool.placeable_item = item
	item_tool.is_multi_step = true
	item_tool.tool_script_path = _placement_script_path(item.placement_category)
	return item_tool

func equip_wheel_entry(entry: Resource, slot_index: int) -> bool:
	var binding := entry as HotbarBinding
	if binding != null and binding.kind == HotbarBinding.KIND_ITEM and binding.item is PlaceableItem:
		return equip_placeable_item(binding.item as PlaceableItem, slot_index)
	if binding != null and binding.kind == HotbarBinding.KIND_TOOL:
		return equip_tool(binding.binding_id, slot_index)
	return equip_tool(str(entry.id) if entry != null else "", slot_index)

func _placement_script_path(category: String) -> String:
	return "res://Scripts/Tools/ConveyorTool.gd" if category == "conveyor" else "res://Scripts/Tools/MachinePlacementTool.gd"

func unequip_tool(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= HOTBAR_SIZE:
		push_error("Invalid slot index: %d" % slot_index)
		return false

	hotbar_tools[slot_index] = null
	_invalidate_active_tool_if_needed("", slot_index)
	return true

func get_tool_in_slot(slot_index: int):
	if slot_index < 0 or slot_index >= HOTBAR_SIZE:
		return null
	return hotbar_tools[slot_index]

func activate_tool(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= HOTBAR_SIZE:
		return

	var tool = hotbar_tools[slot_index]
	if tool and _is_equipped_tool_available(tool ):
		# Emit signal - Player will listen for this and activate the tool itself
		tool_activated.emit(tool.id, slot_index)
	elif tool is HotbarBinding and (tool as HotbarBinding).kind == HotbarBinding.KIND_ITEM:
		var binding := tool as HotbarBinding
		var error := _get_item_availability_error(binding)
		if binding.item is PlaceableItem:
			_cancel_placeable_binding_if_empty(binding, slot_index)
		else:
			UIManager.set_placement_status(error, false)
	else:
		print("No tool in slot %d" % slot_index)

func _is_equipped_tool_available(tool: Resource) -> bool:
	var binding := tool as HotbarBinding
	if binding == null:
		return false
	if binding.kind == HotbarBinding.KIND_ITEM:
		return _get_item_availability_error(binding).is_empty()
	return is_tool_available(binding.binding_id)

func get_placeable_item_id(tool: ToolResource) -> String:
	var item_tool := tool as ItemPlacementToolResource
	return item_tool.binding_id if item_tool != null and item_tool.kind == HotbarBinding.KIND_ITEM else ""

func get_item_binding_id(tool: ToolResource) -> String:
	var binding := tool as HotbarBinding
	return binding.binding_id if binding != null and binding.kind == HotbarBinding.KIND_ITEM else ""

func get_placeable_availability_error(tool: HotbarBinding) -> String:
	if tool == null or tool.kind != HotbarBinding.KIND_ITEM:
		return ""
	if GameStateManager.is_creative_mode():
		return ""
	var item: PlaceableItem = ItemUtils.item_object_by_id(tool.binding_id) as PlaceableItem
	if item == null:
		return "Placeable item is missing"
	if InventoryManager.get_inventory().get_extractable_quantity(tool.binding_id) <= 0:
		return "No %s available" % item.name
	return ""

func _get_item_availability_error(binding: HotbarBinding) -> String:
	if binding == null or binding.kind != HotbarBinding.KIND_ITEM:
		return "No item available"
	if binding.item is PlaceableItem:
		return get_placeable_availability_error(binding)
	if InventoryManager.get_inventory().get_extractable_quantity(binding.binding_id) <= 0:
		return "No %s available" % binding.name
	return ""

func consume_placeable_item(item_id: String) -> bool:
	if GameStateManager.is_creative_mode():
		return true
	var item: InventoryItem = ItemUtils.item_object_by_id(item_id)
	return item != null and InventoryManager.remove_item(item, 1) == 1

func refund_placement(receipt: Dictionary, drop_position: Vector3) -> void:
	if not PlacementReceipt.is_refundable(receipt):
		return
	var item: InventoryItem = ItemUtils.item_object_by_id(str(receipt.get("placement_item_id", "")))
	if item == null:
		return
	var remaining: int = InventoryManager.add_item(item, int(receipt.get("placement_quantity", 0)))
	if remaining > 0:
		MapManager.spawn_item_drop(item, drop_position + Vector3.UP * 1.5, null, remaining, true)

func _cancel_placeable_binding_if_empty(tool: HotbarBinding, slot_index: int) -> void:
	var error: String = get_placeable_availability_error(tool )
	if error.is_empty():
		return
	if slot_index == selected_hotbar_slot:
		var stale_instance := active_tool_instance
		if stale_instance != null and stale_instance.has_method("cancel"):
			stale_instance.cancel()
		active_tool_instance = null
		active_tool_invalidated.emit("")
	hotbar_tools[slot_index] = null
	tool_equipped.emit("", slot_index)
	UIManager.set_placement_status(error, false)

func notify_placeable_placed(item_id: String) -> void:
	if GameStateManager.is_creative_mode() or InventoryManager.get_inventory().get_extractable_quantity(item_id) > 0:
		return
	for slot_index in range(hotbar_tools.size()):
		var tool := hotbar_tools[slot_index] as HotbarBinding
		if tool != null and tool.kind == HotbarBinding.KIND_ITEM and tool.binding_id == item_id and tool.item is PlaceableItem:
			if slot_index == selected_hotbar_slot:
				var stale_instance := active_tool_instance
				if stale_instance != null and stale_instance.has_method("cancel"):
					stale_instance.cancel()
				active_tool_instance = null
				active_tool_invalidated.emit("")
			hotbar_tools[slot_index] = null
			tool_equipped.emit("", slot_index)

func _on_mode_changed(creative_enabled: bool) -> void:
	if creative_enabled:
		return

	for slot_index in range(hotbar_tools.size()):
		var placeable_tool := hotbar_tools[slot_index] as HotbarBinding
		if placeable_tool != null and placeable_tool.item is PlaceableItem and not get_placeable_availability_error(placeable_tool).is_empty():
			_cancel_placeable_binding_if_empty(placeable_tool, slot_index)

	var active_binding: HotbarBinding = null
	if selected_hotbar_slot >= 0:
		active_binding = hotbar_tools[selected_hotbar_slot] as HotbarBinding
	if active_tool_instance != null and active_binding != null and active_binding.kind == HotbarBinding.KIND_TOOL \
		and (active_binding.creative_only or active_binding.structure_placement_tool):
		var stale_instance := active_tool_instance
		if stale_instance.has_method("cancel"):
			stale_instance.cancel()
		active_tool_instance = null
		active_tool_invalidated.emit("")

	for slot_index in range(HOTBAR_SIZE):
		var binding := hotbar_tools[slot_index] as HotbarBinding
		if binding != null and binding.kind == HotbarBinding.KIND_TOOL and (binding.creative_only or binding.structure_placement_tool):
			hotbar_tools[slot_index] = null
			tool_equipped.emit("", slot_index)

func set_selected_hotbar_slot(slot_index: int, tool_id: String) -> void:
	if slot_index < 0 or slot_index >= HOTBAR_SIZE:
		return
	selected_hotbar_slot = slot_index
	_invalidate_active_tool_if_needed(tool_id, slot_index)

func _invalidate_active_tool_if_needed(new_tool_id: String, slot_index: int) -> void:
	if slot_index != selected_hotbar_slot:
		return
	if active_tool_instance == null:
		# Also notify the player when its local reference has somehow drifted
		# from the manager cache.
		active_tool_invalidated.emit(new_tool_id)
		return
	if _get_active_tool_id() == new_tool_id:
		return

	var stale_instance := active_tool_instance
	if stale_instance.has_method("cancel"):
		stale_instance.cancel()
	active_tool_instance = null
	active_tool_invalidated.emit(new_tool_id)

func _get_active_tool_id() -> String:
	if active_tool_instance == null:
		return ""
	if active_tool_instance.has_method("get_tool_id"):
		return str(active_tool_instance.get_tool_id())
	return ""

func get_hotbar_tools() -> Array[Resource]:
	return hotbar_tools.duplicate()


## Saveable interface: get unique save key
func get_save_key() -> String:
	return "tools"


## Get hotbar save data using an explicit kind so tool and item IDs cannot
## collide during future loads.
func get_save_data() -> Dictionary:
	var save_data = []
	for tool in hotbar_tools:
		var binding := tool as HotbarBinding
		if binding != null:
			save_data.append({"kind": binding.kind, "id": binding.binding_id})
		else:
			save_data.append(null)
	return {"hotbar": save_data}


## Load hotbar from save data
func load_save_data(data: Dictionary) -> void:
	# Reset hotbar
	hotbar_tools.clear()
	hotbar_tools.resize(HOTBAR_SIZE)
	for i in range(HOTBAR_SIZE):
		hotbar_tools[i] = null

	var save_data = data.get("hotbar", [])

	# Load structured bindings and migrate the old string-only format.
	for slot_index in range(save_data.size()):
		if slot_index >= HOTBAR_SIZE:
			break
		var saved_binding = save_data[slot_index]
		if saved_binding is Dictionary:
			var kind := str(saved_binding.get("kind", ""))
			var binding_id := str(saved_binding.get("id", ""))
			# Task 4C/4E saves used this temporary shape, accept it while
			# migrating the slot to the generalized item binding.
			if kind.is_empty() and saved_binding.get("type", "") == "placeable":
				kind = HotbarBinding.KIND_ITEM
				binding_id = str(saved_binding.get("item_id", ""))
			_load_binding(kind, binding_id, slot_index)
		elif saved_binding is String and not saved_binding.is_empty():
			_migrate_legacy_string_binding(saved_binding, slot_index)

func _load_binding(kind: String, binding_id: String, slot_index: int) -> void:
	if kind == HotbarBinding.KIND_TOOL and equip_tool(binding_id, slot_index):
		return
	if kind == HotbarBinding.KIND_ITEM:
		var item := ItemUtils.item_object_by_id(binding_id)
		if item != null and _equip_item_definition(item, slot_index):
			return
	_warn_unknown_binding(kind, binding_id, slot_index)

func _migrate_legacy_string_binding(binding_id: String, slot_index: int) -> void:
	# A legacy ID has no kind. Prefer a known tool, matching the old behavior;
	# otherwise resolve it as an inventory item.
	if get_tool(binding_id) != null:
		if equip_tool(binding_id, slot_index):
			return
		_warn_unknown_binding(HotbarBinding.KIND_TOOL, binding_id, slot_index)
		return
	var item := ItemUtils.item_object_by_id(binding_id)
	if item != null and _equip_item_definition(item, slot_index):
		return
	_warn_unknown_binding("legacy", binding_id, slot_index)

func _warn_unknown_binding(kind: String, binding_id: String, slot_index: int) -> void:
	push_warning("Unknown hotbar binding (%s:%s) in slot %d, clearing slot" % [kind, binding_id, slot_index])
	hotbar_tools[slot_index] = null
	tool_equipped.emit("", slot_index)

## Clear tools/hotbar (called during world transitions)
func clear_save_data() -> void:
	if active_tool_instance != null:
		var stale_instance := active_tool_instance
		if stale_instance.has_method("cancel"):
			stale_instance.cancel()
		active_tool_instance = null
		active_tool_invalidated.emit("")
	hotbar_tools.clear()
	hotbar_tools.resize(HOTBAR_SIZE)
	for i in range(HOTBAR_SIZE):
		hotbar_tools[i] = null

extends Node

var tools: Dictionary = {}  # tool_id -> ToolResource
var tool_executor: Node
var hotbar_tools: Array[Resource] = []  # Array of ToolResource or null for each slot (size 10)
var active_tool_instance: Object = null  # Cache the active tool instance so state persists
var selected_hotbar_slot: int = -1

signal tool_equipped(tool_id: String, slot_index: int)
signal tool_activated(tool_id: String, slot_index: int)
signal active_tool_invalidated(new_tool_id: String)

const HOTBAR_SIZE = 10
const TOOLS_PATH = "res://Resources/Tools/"

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
	
	# Register as saveable
	add_to_group("saveable")

func _load_tools() -> void:
	var dir = DirAccess.open(TOOLS_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var tool = load(TOOLS_PATH + file_name)
				if tool and tool is Resource:
					if tool.has_meta("id") or (tool.id if tool.has_method("get") else false):
						var tool_id = tool.id if "id" in tool else ""
						if tool_id:
							tools[tool_id] = tool
							print("Loaded tool: %s from %s" % [tool_id, file_name])
			file_name = dir.get_next()

func get_tool(tool_id: String):
	return tools.get(tool_id)

func get_all_tools() -> Dictionary:
	var available_tools: Dictionary = {}
	for tool_id in tools:
		if is_tool_available(tool_id):
			available_tools[tool_id] = tools[tool_id]
	return available_tools

func is_tool_available(tool_id: String) -> bool:
	var tool: ToolResource = get_tool(tool_id) as ToolResource
	return tool != null and (not tool.creative_only or GameStateManager.is_creative_mode())

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
	
	hotbar_tools[slot_index] = tool
	_invalidate_active_tool_if_needed(tool.id, slot_index)
	tool_equipped.emit(tool_id, slot_index)
	return true

func equip_item(inventory_slot_id: int, slot_index: int):
	if slot_index < 0 or slot_index >= HOTBAR_SIZE:
		push_error("Invalid slot index: %d" % slot_index)
		return false

	if inventory_slot_id < 0 or inventory_slot_id >= InventoryManager.inventory.inventory_size:
		push_error("Invalid inventory index: %d" % slot_index)
		return false

	var item = InventoryManager.inventory.get_slot_item(inventory_slot_id).item
	var itemTool = get_tool("item").duplicate()
	itemTool.id = item.id

	hotbar_tools[slot_index] = itemTool
	_invalidate_active_tool_if_needed(itemTool.id, slot_index)
	tool_equipped.emit(item.id, slot_index)
	return true

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
	if tool and is_tool_available(tool.id):
		# Emit signal - Player will listen for this and activate the tool itself
		tool_activated.emit(tool.id, slot_index)
	else:
		print("No tool in slot %d" % slot_index)

func _on_mode_changed(creative_enabled: bool) -> void:
	if creative_enabled:
		return

	var active_tool_id := _get_active_tool_id()
	var active_tool_resource: ToolResource = get_tool(active_tool_id) as ToolResource
	if active_tool_instance != null and active_tool_resource != null and active_tool_resource.creative_only:
		var stale_instance := active_tool_instance
		if stale_instance.has_method("cancel"):
			stale_instance.cancel()
		active_tool_instance = null
		active_tool_invalidated.emit("")

	for slot_index in range(HOTBAR_SIZE):
		var tool: ToolResource = hotbar_tools[slot_index] as ToolResource
		if tool != null and tool.creative_only:
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


## Get hotbar save data (tool IDs only)
func get_save_data() -> Dictionary:
	var save_data = []
	for tool in hotbar_tools:
		if tool:
			save_data.append(tool.id)
		else:
			save_data.append(null)
	return { "hotbar": save_data }


## Load hotbar from save data
func load_save_data(data: Dictionary) -> void:
	# Reset hotbar
	hotbar_tools.clear()
	hotbar_tools.resize(HOTBAR_SIZE)
	for i in range(HOTBAR_SIZE):
		hotbar_tools[i] = null
	
	var save_data = data.get("hotbar", [])
	
	# Load tools from save data
	for slot_index in range(save_data.size()):
		if slot_index >= HOTBAR_SIZE:
			break
		
		var tool_id = save_data[slot_index]
		if tool_id and tool_id != null:
			if not equip_tool(tool_id, slot_index):
				# Keep the UI synchronized when a tool is unavailable in this mode.
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

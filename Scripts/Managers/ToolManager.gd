extends Node

var tools: Dictionary = {}  # tool_id -> ToolResource
var tool_executor: Node
var hotbar_tools: Array[Resource] = []  # Array of ToolResource or null for each slot (size 10)
var active_tool_instance: Object = null  # Cache the active tool instance so state persists

signal tool_equipped(tool_id: String, slot_index: int)
signal tool_activated(tool_id: String, slot_index: int)

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
	return tools.duplicate()

func equip_tool(tool_id: String, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= HOTBAR_SIZE:
		push_error("Invalid slot index: %d" % slot_index)
		return false
	
	var tool = get_tool(tool_id)
	if not tool:
		push_error("Tool not found: %s" % tool_id)
		return false
	
	hotbar_tools[slot_index] = tool
	tool_equipped.emit(tool_id, slot_index)
	return true

func unequip_tool(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= HOTBAR_SIZE:
		push_error("Invalid slot index: %d" % slot_index)
		return false
	
	hotbar_tools[slot_index] = null
	return true

func get_tool_in_slot(slot_index: int):
	if slot_index < 0 or slot_index >= HOTBAR_SIZE:
		return null
	return hotbar_tools[slot_index]

func activate_tool(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= HOTBAR_SIZE:
		return
	
	var tool = hotbar_tools[slot_index]
	if tool:
		# Emit signal - Player will listen for this and activate the tool itself
		tool_activated.emit(tool.id, slot_index)
	else:
		print("No tool in slot %d" % slot_index)

func get_hotbar_tools() -> Array[Resource]:
	return hotbar_tools.duplicate()


## Get hotbar save data (tool IDs only)
func get_save_data() -> Array:
	var save_data = []
	for tool in hotbar_tools:
		if tool:
			save_data.append(tool.id)
		else:
			save_data.append(null)
	return save_data


## Load hotbar from save data
func load_save_data(save_data: Array) -> void:
	# Reset hotbar
	hotbar_tools.clear()
	hotbar_tools.resize(HOTBAR_SIZE)
	for i in range(HOTBAR_SIZE):
		hotbar_tools[i] = null
	
	# Load tools from save data
	for slot_index in range(save_data.size()):
		if slot_index >= HOTBAR_SIZE:
			break
		
		var tool_id = save_data[slot_index]
		if tool_id and tool_id != null:
			equip_tool(tool_id, slot_index)

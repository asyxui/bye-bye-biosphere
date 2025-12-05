extends Node
class_name ToolExecutor

var player: Node

func _ready() -> void:
	pass

func execute_tool(tool, executor_player: Node) -> Object:
	player = executor_player
	
	if not tool or not tool.tool_script_path:
		push_error("Invalid tool or tool_script_path not set")
		return null
	
	# Load and instantiate the tool script
	var tool_script = load(tool.tool_script_path)
	if not tool_script:
		push_error("Failed to load tool script: " + tool.tool_script_path)
		return null
	
	# Create an instance and call execute
	var tool_instance = tool_script.new()
	if tool_instance.has_method("execute"):
		tool_instance.execute(player)
		return tool_instance
	else:
		push_error("Tool script does not have an execute(player) method: " + tool.tool_script_path)
		return null

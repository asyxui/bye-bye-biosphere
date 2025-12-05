## BaseTool.gd
## Base class for all tools providing a clean, reusable interface
## 
## Subclasses should override:
## - on_activate(player): Called on first activation
## - on_execute(player): Called on each execution
## - on_cancel(): Called when canceling (optional)
## - is_multi_step(): Return true for multi-step tools that maintain state

extends RefCounted
class_name BaseTool

var player: Node = null
var _is_active: bool = false
var _tool_resource: ToolResource = null  # Reference to the tool resource for metadata

## Set the tool resource for metadata access
func set_tool_resource(tool_resource: ToolResource) -> void:
	_tool_resource = tool_resource

## Called when the tool is first activated with a player
func on_activate(p: Node) -> void:
	player = p
	_is_active = true

## Called each time the tool is executed (first click or subsequent clicks)
func on_execute(_p: Node) -> void:
	pass

## Called when the tool is canceled (right-click or tool switch)
func on_cancel() -> void:
	pass

## Called during _process to update previews or state
func on_update(_delta: float) -> void:
	pass

## Return true for multi-step tools that need to maintain state between clicks
## Return false for single-action tools
## Can be overridden or set via ToolResource.is_multi_step
func is_multi_step() -> bool:
	# If we have a tool resource reference, use its setting
	if _tool_resource:
		return _tool_resource.is_multi_step
	return false

## Public execute method - handles state management automatically
func execute(p: Node) -> void:
	if not _is_active:
		on_activate(p)
	
	if p != null:
		player = p
	
	on_execute(player)
	
	# Single-step tools automatically clear themselves
	if not is_multi_step():
		clear()

## Cancel the tool and clean up
func cancel() -> void:
	on_cancel()
	clear()

## Clear the tool state
func clear() -> void:
	_is_active = false
	player = null

## Update method for tools that need per-frame updates
func update(delta: float) -> void:
	if _is_active:
		on_update(delta)

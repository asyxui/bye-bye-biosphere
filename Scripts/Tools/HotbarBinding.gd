extends ToolResource
class_name HotbarBinding

## A hotbar entry keeps its source kind and stable ID separate from the
## execution identity used by the placement/tool runtime.
const KIND_TOOL := "tool"
const KIND_ITEM := "item"

var kind: String = ""
var binding_id: String = ""
var item: InventoryItem = null

func configure_tool(source: ToolResource) -> void:
	kind = KIND_TOOL
	binding_id = str(source.id)
	id = "%s:%s" % [kind, binding_id]
	name = source.name
	description = source.description
	icon = source.icon
	tool_script_path = source.tool_script_path
	is_multi_step = source.is_multi_step
	creative_only = source.creative_only
	structure_placement_tool = source.structure_placement_tool
	item = null

func configure_item(source: InventoryItem) -> void:
	kind = KIND_ITEM
	binding_id = str(source.id)
	id = "%s:%s" % [kind, binding_id]
	name = source.name
	description = source.description
	icon = source.icon
	tool_script_path = "res://Scripts/Tools/ItemTool.gd"
	is_multi_step = false
	creative_only = false
	structure_placement_tool = false
	item = source

func get_display_name() -> String:
	if kind == KIND_ITEM and item != null and not item.name.is_empty():
		return item.name
	if not name.is_empty():
		return name
	return binding_id

func get_display_description() -> String:
	return description if not description.is_empty() else get_display_name()

func get_display_icon() -> Texture2D:
	if kind == KIND_ITEM and item != null and item.icon != null:
		return item.icon
	return icon

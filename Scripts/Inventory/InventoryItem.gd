## InventoryItem.gd
## Represents a single item type with metadata
class_name InventoryItem
extends Resource

@export var id: String  ## Unique identifier for the item
@export var name: String  ## Display name
@export var description: String  ## Item description
@export var max_stack_size: int = 1  ## Max items in one stack
@export var icon: Texture2D  ## Item icon for UI
@export var weight: float = 0.0  ## Weight per item for encumbrance
@export var rarity: String = "common"  ## Item rarity: common, uncommon, rare, epic, legendary
@export var dropColor: Color = Color.BLACK ## Color of the drop (currently just a small ball

func _init(p_id: String = "", p_name: String = "", p_max_stack: int = 1, p_icon: Texture2D = null) -> void:
	id = p_id
	name = p_name
	max_stack_size = p_max_stack
	icon = p_icon

func get_display_name() -> String:
	return name

func get_rarity_color() -> Color:
	match rarity:
		"common":
			return Color.WHITE
		"uncommon":
			return Color.GREEN
		"rare":
			return Color.CYAN
		"epic":
			return Color.BLUE
		"legendary":
			return Color.YELLOW
		_:
			return Color.WHITE

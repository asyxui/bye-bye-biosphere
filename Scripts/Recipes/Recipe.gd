## Data-only definition for a machine transformation.
class_name Recipe
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var input_item_ids: Array[String] = []
@export var input_quantities: Array[int] = []
@export var output_item_id: String = ""
@export var output_quantity: int = 1
@export var processing_duration: float = 2.0
@export var crafting_duration: float = 0.0
@export var ecological_damage: float = 0.0
@export var handcraftable: bool = false
@export var crafting_category: String = ""

func get_display_name() -> String:
	return display_name if not display_name.is_empty() else id

func get_input_requirements() -> Dictionary:
	var requirements: Dictionary = {}
	for index in range(mini(input_item_ids.size(), input_quantities.size())):
		var item_id: String = input_item_ids[index]
		var quantity: int = input_quantities[index]
		if not item_id.is_empty() and quantity > 0:
			requirements[item_id] = quantity
	return requirements

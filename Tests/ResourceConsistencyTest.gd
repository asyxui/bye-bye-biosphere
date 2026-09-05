## Headless validation for the canonical material and crafting graph.
extends "res://Tests/TestCase.gd"

const CANONICAL_ITEMS := {
	"stone": "8",
	"iron_ore": "6",
	"iron_ingot": "5",
	"manual_smelter": "9",
	"smelter": "10",
	"sink": "11",
	"conveyor": "12"
}
const PLACEABLE_STRUCTURES := {
	"9": "manual_smelter",
	"10": "smelter",
	"11": "sink",
	"12": "conveyor"
}

func _run() -> void:
	check(ItemUtils.get_all_items().size() >= CANONICAL_ITEMS.size())
	check(Handcrafting.get_recipes().size() == 4)
	for recipe in Handcrafting.get_recipes():
		for input_id in recipe.input_item_ids:
			check(ItemUtils.item_object_by_id(input_id) != null)
		check(ItemUtils.item_object_by_id(recipe.output_item_id) != null)

	for item_id in PLACEABLE_STRUCTURES:
		var item := ItemUtils.item_object_by_id(item_id)
		check(item is PlaceableItem)
		var structure_type := (item as PlaceableItem).structure_type
		if structure_type == "conveyor":
			check(ConveyorConnectionManager.conveyor_scene != null)
		else:
			check(MachineManager.get_machine_scene(structure_type) != null)

	check(BiosphereManager.CONFIG.objective_item_id == CANONICAL_ITEMS["iron_ingot"])
	check(ItemUtils.item_object_by_id("7") == null)

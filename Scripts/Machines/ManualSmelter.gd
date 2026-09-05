extends Smelter
class_name ManualSmelter

const MANUAL_SMELTING_RECIPE: Recipe = preload("res://Resources/Recipes/ManualSmelting.tres")

func _ready() -> void:
	machine_type = "manual_smelter"
	input_buffer = ItemBuffer.new(1, 4)
	output_buffer = ItemBuffer.new(1, 4)
	active_recipe = MANUAL_SMELTING_RECIPE
	super._ready()

func load_machine_state(state: Dictionary) -> void:
	var restored_state := state.duplicate(true)
	# The base smelter loader resolves the regular recipe by default; force the
	# manual recipe for this specialized structure so its slower duration and
	# ecological cost survive save/load.
	restored_state["active_recipe_id"] = MANUAL_SMELTING_RECIPE.id
	super.load_machine_state(restored_state)

func _load_recipe_by_id(recipe_id: String) -> Recipe:
	if recipe_id == MANUAL_SMELTING_RECIPE.id:
		return MANUAL_SMELTING_RECIPE
	return super._load_recipe_by_id(recipe_id)

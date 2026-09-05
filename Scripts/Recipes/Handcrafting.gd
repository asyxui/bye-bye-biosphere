class_name Handcrafting
extends RefCounted

const RECIPES_PATH := "res://Resources/Recipes/Handcrafting"
const RECIPE_ORDER := ["manual_smelter", "smelter", "sink", "conveyor"]

static func get_recipes() -> Array[Recipe]:
	var recipes: Array[Recipe] = []
	for filename in ResourceLoader.list_directory(RECIPES_PATH):
		if not filename.ends_with(".tres"):
			continue
		var recipe = load(RECIPES_PATH.path_join(filename))
		if recipe is Recipe and recipe.handcraftable:
			recipes.append(recipe)
	recipes.sort_custom(func(a: Recipe, b: Recipe) -> bool:
		var a_index := RECIPE_ORDER.find(a.id)
		var b_index := RECIPE_ORDER.find(b.id)
		if a_index == -1:
			a_index = RECIPE_ORDER.size()
		if b_index == -1:
			b_index = RECIPE_ORDER.size()
		return (a_index == b_index and a.id < b.id) or a_index < b_index
	)
	return recipes

static func get_missing(recipe: Recipe, inventory: Inventory) -> Dictionary:
	if recipe == null or inventory == null or not GameStateManager.ingredient_costs_enabled():
		return {}
	var missing: Dictionary = {}
	var requirements := recipe.get_input_requirements()
	for item_id in requirements:
		var required: int = int(requirements[item_id])
		var available := inventory.get_extractable_quantity(str(item_id))
		if available < required:
			missing[str(item_id)] = required - available
	return missing

static func can_craft(recipe: Recipe, inventory: Inventory) -> bool:
	if recipe == null or inventory == null or not recipe.handcraftable:
		return false
	var output_item: InventoryItem = ItemUtils.item_object_by_id(recipe.output_item_id)
	if output_item == null or recipe.output_quantity <= 0:
		return false
	var output_stack := ItemStack.new(output_item, recipe.output_quantity)
	if inventory.get_insertable_quantity(output_stack, recipe.output_quantity) < recipe.output_quantity:
		return false
	return get_missing(recipe, inventory).is_empty()

static func craft(recipe: Recipe, inventory: Inventory) -> bool:
	if not can_craft(recipe, inventory):
		return false

	var output_item: InventoryItem = ItemUtils.item_object_by_id(recipe.output_item_id)
	var removed: Dictionary = {}
	if GameStateManager.ingredient_costs_enabled():
		var requirements := recipe.get_input_requirements()
		for item_key in requirements:
			var item_id := str(item_key)
			var required: int = int(requirements[item_key])
			var input_item: InventoryItem = ItemUtils.item_object_by_id(item_id)
			var extracted := inventory.extract_stack(item_id, required)
			if input_item == null or extracted == null or extracted.quantity != required:
				if extracted != null and extracted.quantity > 0:
					inventory.add_item(input_item, extracted.quantity)
				_restore_inputs(removed, inventory)
				return false
			removed[item_id] = required

	var output_stack := ItemStack.new(output_item, recipe.output_quantity)
	var inserted := inventory.insert_stack(output_stack, recipe.output_quantity)
	if inserted != recipe.output_quantity:
		if inserted > 0:
			inventory.remove_item(output_item, inserted)
		_restore_inputs(removed, inventory)
		return false

	inventory.items_changed.emit()
	return true

static func _restore_inputs(removed: Dictionary, inventory: Inventory) -> void:
	for item_id in removed:
		var item: InventoryItem = ItemUtils.item_object_by_id(str(item_id))
		if item != null:
			inventory.add_item(item, int(removed[item_id]))

static func format_missing(missing: Dictionary) -> String:
	if missing.is_empty():
		return ""
	var requirements: Array[String] = []
	for item_key in missing:
		var item_id := str(item_key)
		var item: InventoryItem = ItemUtils.item_object_by_id(item_id)
		var item_name := item.get_display_name() if item != null else item_id
		requirements.append("%d %s" % [int(missing[item_key]), item_name])
	return "Missing: " + ", ".join(requirements)

class_name Handcrafting
extends RefCounted

const RECIPES_PATH := "res://Resources/Recipes/Handcrafting"

static func get_recipes() -> Array[Recipe]:
	var recipes: Array[Recipe] = []
	var recipes_dir := DirAccess.open(RECIPES_PATH)
	if recipes_dir == null:
		return recipes

	recipes_dir.list_dir_begin()
	var filename := recipes_dir.get_next()
	while not filename.is_empty():
		if not recipes_dir.current_is_dir() and filename.ends_with(".tres"):
			var recipe = load(RECIPES_PATH.path_join(filename))
			if recipe is Recipe and recipe.handcraftable:
				recipes.append(recipe)
		filename = recipes_dir.get_next()
	recipes_dir.list_dir_end()
	recipes.sort_custom(func(a: Recipe, b: Recipe) -> bool: return a.id < b.id)
	return recipes

static func get_missing(recipe: Recipe, inventory: Inventory) -> Dictionary:
	if recipe == null or inventory == null or not GameStateManager.construction_costs_enabled():
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
	if GameStateManager.construction_costs_enabled():
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

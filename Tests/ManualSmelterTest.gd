## Headless smoke tests for manual smelting and interaction transactions.
extends "res://Tests/TestCase.gd"

const MANUAL_SMELTER_SCENE: PackedScene = preload("res://Scenes/Machines/ManualSmelter.tscn")
const IRON_ORE: InventoryItem = preload("res://Resources/Items/IronOre.tres")
const IRON_INGOT_ID: String = "5"
const FIXED_STEP: float = 1.0 / 60.0

func _run() -> void:
	InventoryManager.clear_save_data()
	var manual: ManualSmelter = MANUAL_SMELTER_SCENE.instantiate() as ManualSmelter
	root.add_child(manual)

	check(manual.find_children("*", "ConnectionPoint", true, false).is_empty())
	check(manual.get_interaction_prompt(null) == "No Iron Ore")
	check(InventoryManager.add_item(IRON_ORE, 1) == 0)
	check(manual.get_interaction_prompt(null) == "E: Insert Iron Ore")
	check(manual.interact(null))
	check(InventoryManager.get_inventory().get_extractable_quantity(IRON_ORE.id) == 0)
	check(manual.get_input_buffer().get_extractable_quantity(IRON_ORE.id) == 1)

	manual._simulate_step(FIXED_STEP)
	var progress_state := manual.get_machine_state()
	var progress_restored: ManualSmelter = MANUAL_SMELTER_SCENE.instantiate() as ManualSmelter
	root.add_child(progress_restored)
	progress_restored.load_machine_state(progress_state)
	check(is_equal_approx(progress_restored.processing_progress, manual.processing_progress))
	check(is_equal_approx(progress_restored.active_recipe.processing_duration, 5.0))
	check(progress_restored.get_input_buffer().get_extractable_quantity(IRON_ORE.id) == 0)
	progress_restored.queue_free()

	for _step in range(300):
		manual._simulate_step(FIXED_STEP)
	check(manual.get_output_buffer().get_extractable_quantity(IRON_INGOT_ID) == 1)
	check(manual.get_interaction_prompt(null) == "E: Collect Iron Ingot")
	check(manual.interact(null))
	check(InventoryManager.get_inventory().get_extractable_quantity(IRON_INGOT_ID) == 1)
	check(not manual.interact(null))

	var saved_state := manual.get_machine_state()
	var restored: ManualSmelter = MANUAL_SMELTER_SCENE.instantiate() as ManualSmelter
	root.add_child(restored)
	restored.load_machine_state(saved_state)
	check(restored.get_machine_state().get("active_recipe_id", "") == "manual_smelting")
	check(restored.get_machine_state().get("input_buffer", []).is_empty())
	check(restored.get_machine_state().get("output_buffer", []).is_empty())

	manual.queue_free()
	restored.queue_free()
	InventoryManager.clear_save_data()

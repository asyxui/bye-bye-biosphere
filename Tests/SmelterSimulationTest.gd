## Headless smoke tests for the first recipe-driven machine.
extends "res://Tests/TestCase.gd"

const SMELTER_SCENE: PackedScene = preload("res://Scenes/Machines/Smelter.tscn")
const ORE_ID: String = "6"
const INGOT_ID: String = "5"
const FIXED_STEP: float = 1.0 / 60.0

func _run() -> void:
	var smelter: Smelter = SMELTER_SCENE.instantiate() as Smelter
	root.add_child(smelter)
	var input_buffer: ItemBuffer = smelter.get_input_buffer()
	var output_buffer: ItemBuffer = smelter.get_output_buffer()

	check(input_buffer.insert_stack(ItemStack.new(ORE_ID, 1)) == 1)
	for _step in range(130):
		smelter._simulate_step(FIXED_STEP)
	check(output_buffer.get_extractable_quantity(INGOT_ID) == 1)
	check(smelter.get_processing_state_name() == "Input-starved")

	# A full output stack holds the completed result without losing the consumed
	# ore. Clearing the destination lets the pending result finish normally.
	output_buffer.extract_stack(INGOT_ID, 1)
	check(output_buffer.insert_stack(ItemStack.new(INGOT_ID, 64)) == 64)
	check(input_buffer.insert_stack(ItemStack.new(ORE_ID, 1)) == 1)
	for _step in range(130):
		smelter._simulate_step(FIXED_STEP)
	check(smelter.get_processing_state_name() == "Output-blocked")
	check(input_buffer.get_extractable_quantity(ORE_ID) == 0)

	output_buffer.extract_stack(INGOT_ID, 64)
	smelter._simulate_step(FIXED_STEP)
	check(output_buffer.get_extractable_quantity(INGOT_ID) == 1)

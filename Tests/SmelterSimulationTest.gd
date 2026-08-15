## Headless smoke tests for the first recipe-driven machine.
extends SceneTree

const SMELTER_SCENE: PackedScene = preload("res://Scenes/Machines/Smelter.tscn")
const ORE_ID: String = "2"
const INGOT_ID: String = "3"
const FIXED_STEP: float = 1.0 / 60.0

func _initialize() -> void:
	var smelter: Smelter = SMELTER_SCENE.instantiate() as Smelter
	root.add_child(smelter)
	var input_buffer: ItemBuffer = smelter.get_input_buffer()
	var output_buffer: ItemBuffer = smelter.get_output_buffer()

	assert(input_buffer.insert_stack(ItemStack.new(ORE_ID, 1)) == 1)
	for _step in range(130):
		smelter._simulate_step(FIXED_STEP)
	assert(output_buffer.get_extractable_quantity(INGOT_ID) == 1)
	assert(smelter.get_processing_state_name() == "Idle")

	# A full output stack holds the completed result without losing the consumed
	# ore. Clearing the destination lets the pending result finish normally.
	output_buffer.extract_stack(INGOT_ID, 1)
	assert(output_buffer.insert_stack(ItemStack.new(INGOT_ID, 64)) == 64)
	assert(input_buffer.insert_stack(ItemStack.new(ORE_ID, 1)) == 1)
	for _step in range(130):
		smelter._simulate_step(FIXED_STEP)
	assert(smelter.get_processing_state_name() == "Output-blocked")
	assert(input_buffer.get_extractable_quantity(ORE_ID) == 0)

	output_buffer.extract_stack(INGOT_ID, 64)
	smelter._simulate_step(FIXED_STEP)
	assert(output_buffer.get_extractable_quantity(INGOT_ID) == 1)

	quit()

## Headless smoke test for the data contracts used by save/load restoration.
extends SceneTree

const ORE_ID: String = "2"
const INGOT_ID: String = "3"
const SMELTER_SCENE: PackedScene = preload("res://Scenes/Machines/Smelter.tscn")

func _initialize() -> void:
	# Machine and inventory buffers retain item identifiers, quantities, and
	# metadata without depending on their scene nodes.
	var buffer := ItemBuffer.new(2, 64)
	var source_stack := ItemStack.new(ORE_ID, 3, {"test_batch": 7})
	assert(buffer.insert_stack(source_stack, 2) == 2)
	assert(source_stack.quantity == 1)
	var restored_buffer := ItemBuffer.new(2, 64)
	restored_buffer.load_dict(buffer.to_dict())
	assert(restored_buffer.get_extractable_quantity(ORE_ID) == 2)
	assert(restored_buffer.peek_stack(ORE_ID).metadata.get("test_batch") == 7)

	# Conveyor geometry, stable downstream references, and logical item
	# positions survive independently of presentation nodes.
	var belt := ConveyorBeltObject.new(Vector3.ZERO, Vector3(10, 0, 0), "belt_a")
	belt.downstream_belt_id = "belt_b"
	belt.items.append(ConveyorItem.new(INGOT_ID, 1, 0.65, {"test_batch": 8}))
	var restored_belt := ConveyorBeltObject.from_dict(belt.to_dict())
	assert(restored_belt != null)
	assert(restored_belt.belt_id == "belt_a")
	assert(restored_belt.downstream_belt_id == "belt_b")
	assert(is_equal_approx(restored_belt.items[0].progress, 0.65))

	# A smelter's in-flight recipe state is restored after the machine exists,
	# before conveyor contents are allowed to resume simulation.
	var smelter: Smelter = SMELTER_SCENE.instantiate() as Smelter
	root.add_child(smelter)
	smelter.get_input_buffer().insert_stack(ItemStack.new(ORE_ID, 1))
	smelter._simulate_step(1.0 / 60.0)
	var machine_state: Dictionary = smelter.get_machine_state()
	var restored_smelter: Smelter = SMELTER_SCENE.instantiate() as Smelter
	root.add_child(restored_smelter)
	restored_smelter.load_machine_state(machine_state)
	assert(is_equal_approx(restored_smelter.processing_progress, smelter.processing_progress))
	assert(restored_smelter.get_processing_state_name() == smelter.get_processing_state_name())
	assert(restored_smelter.get_input_buffer().get_total_quantity() == smelter.get_input_buffer().get_total_quantity())
	quit()

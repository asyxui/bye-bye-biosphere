## Headless smoke tests for deterministic logical conveyor movement.
extends SceneTree

const ORE := preload("res://Resources/Items/Ore.tres")
const FIXED_STEP: float = 1.0 / 60.0

func _initialize() -> void:
	var belt := ConveyorBeltObject.new(Vector3.ZERO, Vector3(20, 0, 0))
	var source := ItemBuffer.new(1, 64)
	var source_stack := ItemStack.new(ORE, 2)
	assert(source.insert_stack(source_stack) == 2)

	# The first item can be transferred, while the second remains at the source
	# until the belt has advanced enough to create start spacing.
	assert(ItemTransfer.transfer(source, belt, ORE.id, 1) == 1)
	assert(belt.items.size() == 1)
	assert(source.get_extractable_quantity(ORE.id) == 1)
	assert(belt.get_insertable_quantity(ItemStack.new(ORE, 1), 1) == 0)
	belt.advance_items(0.5)
	assert(belt.get_insertable_quantity(ItemStack.new(ORE, 1), 1) == 1)

	# Ten logical items retain order and minimum spacing after movement.
	for index in range(9):
		var next_stack := ItemStack.new(ORE, 1)
		while belt.get_insertable_quantity(next_stack, 1) == 0:
			belt.advance_items(FIXED_STEP)
		assert(belt.insert_stack(next_stack, 1) == 1)
	assert(belt.items.size() == 10)
	belt.advance_items(2.0)
	for index in range(1, belt.items.size()):
		assert(belt.items[index - 1].progress - belt.items[index].progress >= belt.get_spacing_progress() - 0.0001)

	# Extraction remains FIFO even when all items share the same item type.
	var extracted := belt.extract_stack(ORE.id, 1)
	assert(extracted != null and extracted.quantity == 1)
	assert(belt.items.size() == 9)

	quit()

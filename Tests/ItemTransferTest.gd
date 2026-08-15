## Headless smoke tests for the shared item-transfer contract.
## Run with Godot's headless script runner when available.
extends SceneTree

const ORE := preload("res://Resources/Items/Ore.tres")
const APPLE := preload("res://Resources/Items/Apple.tres")

func _initialize() -> void:
	var source := ItemBuffer.new(2, 64)
	var destination := ItemBuffer.new(1, 2)
	var seed_stack := ItemStack.new(ORE, 5)
	assert(source.insert_stack(seed_stack) == 5)
	assert(seed_stack.quantity == 0)

	# Partial transfer: destination accepts two and the source retains three.
	assert(ItemTransfer.transfer(source, destination, ORE.id, 5) == 2)
	assert(source.get_extractable_quantity(ORE.id) == 3)
	assert(destination.get_extractable_quantity(ORE.id) == 2)
	assert(source.get_extractable_quantity(ORE.id) + destination.get_extractable_quantity(ORE.id) == 5)

	# Failed transfer: incompatible destination leaves the source unchanged.
	var blocked := ItemBuffer.new(1, 2)
	var apple_stack := ItemStack.new(APPLE, 2)
	blocked.insert_stack(apple_stack)
	var source_before := source.get_extractable_quantity(ORE.id)
	assert(ItemTransfer.transfer(source, blocked, ORE.id, 1) == 0)
	assert(source.get_extractable_quantity(ORE.id) == source_before)

	# The same ore resource can be held by inventory and a conveyor segment.
	var inventory := Inventory.new(2)
	assert(inventory.add_item(ORE, 1) == 0)
	var belt := ConveyorBeltObject.new(Vector3.ZERO, Vector3.ONE)
	assert(ItemTransfer.transfer(inventory, belt, ORE.id, 1) == 1)
	assert(inventory.get_extractable_quantity(ORE.id) == 0)
	assert(belt.items.size() == 1)
	assert(belt.items[0] is ConveyorItem)
	assert(belt.items[0].item_id == ORE.id)

	quit()

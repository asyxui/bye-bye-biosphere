## Headless smoke tests for the shared item-transfer contract.
## Run with Godot's headless script runner when available.
extends "res://Tests/TestCase.gd"

const ORE := preload("res://Resources/Items/IronOre.tres")
const APPLE := preload("res://Resources/Items/Apple.tres")

func _run() -> void:
	var source := ItemBuffer.new(2, 64)
	var destination := ItemBuffer.new(1, 2)
	var seed_stack := ItemStack.new(ORE, 5)
	check(source.insert_stack(seed_stack) == 5)
	check(seed_stack.quantity == 0)

	# Partial transfer: destination accepts two and the source retains three.
	check(ItemTransfer.transfer(source, destination, ORE.id, 5) == 2)
	check(source.get_extractable_quantity(ORE.id) == 3)
	check(destination.get_extractable_quantity(ORE.id) == 2)
	check(source.get_extractable_quantity(ORE.id) + destination.get_extractable_quantity(ORE.id) == 5)

	# Failed transfer: incompatible destination leaves the source unchanged.
	var blocked := ItemBuffer.new(1, 2)
	var apple_stack := ItemStack.new(APPLE, 2)
	blocked.insert_stack(apple_stack)
	var source_before := source.get_extractable_quantity(ORE.id)
	check(ItemTransfer.transfer(source, blocked, ORE.id, 1) == 0)
	check(source.get_extractable_quantity(ORE.id) == source_before)

	# The same ore resource can be held by inventory and a conveyor segment.
	var inventory := Inventory.new(2)
	check(inventory.add_item(ORE, 1) == 0)
	var belt := ConveyorBeltObject.new(Vector3.ZERO, Vector3.ONE)
	check(ItemTransfer.transfer(inventory, belt, ORE.id, 1) == 1)
	check(inventory.get_extractable_quantity(ORE.id) == 0)
	check(belt.items.size() == 1)
	check(belt.items[0] is ConveyorItem)
	check(belt.items[0].item_id == ORE.id)

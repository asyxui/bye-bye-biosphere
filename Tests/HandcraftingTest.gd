## Headless smoke tests for handcrafting transactions.
extends "res://Tests/TestCase.gd"

const MANUAL_SMELTER := preload("res://Resources/Recipes/Handcrafting/ManualSmelter.tres")
const STONE := preload("res://Resources/Items/Stone.tres")

func _run() -> void:
	GameStateManager.set_creative_mode(false)

	var inventory := Inventory.new(2)
	check(inventory.add_item(STONE, 12) == 0)
	check(Handcrafting.can_craft(MANUAL_SMELTER, inventory))
	check(Handcrafting.craft(MANUAL_SMELTER, inventory))
	check(inventory.get_extractable_quantity(STONE.id) == 0)
	check(inventory.get_extractable_quantity("9") == 1)

	var blocked_inventory := Inventory.new(1)
	check(blocked_inventory.add_item(STONE, 12) == 0)
	check(not Handcrafting.craft(MANUAL_SMELTER, blocked_inventory))
	check(blocked_inventory.get_extractable_quantity(STONE.id) == 12)
	check(blocked_inventory.get_extractable_quantity("9") == 0)

	GameStateManager.set_creative_mode(true)
	var creative_inventory := Inventory.new(1)
	check(Handcrafting.craft(MANUAL_SMELTER, creative_inventory))
	check(creative_inventory.get_extractable_quantity("9") == 1)
	GameStateManager.set_creative_mode(false)

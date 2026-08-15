## Headless smoke tests for handcrafting transactions.
extends SceneTree

const MANUAL_SMELTER := preload("res://Resources/Recipes/Handcrafting/ManualSmelter.tres")
const ROCK := preload("res://Resources/Items/Rock.tres")

func _initialize() -> void:
	GameStateManager.set_creative_mode(false)

	var inventory := Inventory.new(2)
	assert(inventory.add_item(ROCK, 12) == 0)
	assert(Handcrafting.can_craft(MANUAL_SMELTER, inventory))
	assert(Handcrafting.craft(MANUAL_SMELTER, inventory))
	assert(inventory.get_extractable_quantity(ROCK.id) == 0)
	assert(inventory.get_extractable_quantity("9") == 1)

	var blocked_inventory := Inventory.new(1)
	assert(blocked_inventory.add_item(ROCK, 12) == 0)
	assert(not Handcrafting.craft(MANUAL_SMELTER, blocked_inventory))
	assert(blocked_inventory.get_extractable_quantity(ROCK.id) == 12)
	assert(blocked_inventory.get_extractable_quantity("9") == 0)

	GameStateManager.set_creative_mode(true)
	var creative_inventory := Inventory.new(1)
	assert(Handcrafting.craft(MANUAL_SMELTER, creative_inventory))
	assert(creative_inventory.get_extractable_quantity("9") == 1)
	GameStateManager.set_creative_mode(false)
	quit()

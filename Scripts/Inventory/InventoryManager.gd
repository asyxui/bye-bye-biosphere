## InventoryManager.gd
## Singleton manager for the player's inventory
extends Node

var inventory = null  # Inventory type
var is_inventory_open: bool = false

func _ready() -> void:
	var inventory_class = load("res://Scripts/Inventory/Inventory.gd")
	inventory = inventory_class.new(20)
	inventory.max_weight = 100.0

## Add item to player inventory
func add_item(item, quantity: int = 1) -> int:
	return inventory.add_item(item, quantity)

## Remove item from player inventory
func remove_item(item, quantity: int = 1) -> int:
	return inventory.remove_item(item, quantity)

## Get item count in inventory
func get_item_count(item) -> int:
	return inventory.get_item_count(item)

## Get inventory reference
func get_inventory():
	return inventory

## Toggle inventory UI
func toggle_inventory() -> void:
	is_inventory_open = not is_inventory_open

## Get total inventory weight
func get_weight_percent() -> float:
	return inventory.get_total_weight() / inventory.max_weight

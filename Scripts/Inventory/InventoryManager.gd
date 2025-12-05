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


## Get inventory save data (serialize for saving)
func get_save_data() -> Array:
	var save_data = []
	for slot in inventory.slots:
		if not slot.is_empty() and slot.item:
			save_data.append({
				"item_id": slot.item.id,
				"quantity": slot.quantity
			})
		else:
			save_data.append(null)
	return save_data


## Load inventory from save data
func load_save_data(save_data: Array) -> void:
	if not inventory:
		return
	
	# Clear current inventory
	inventory._initialize_slots()
	
	# Load items from save data
	for slot_index in range(save_data.size()):
		if slot_index >= inventory.inventory_size:
			break
		
		var slot_data = save_data[slot_index]
		if slot_data == null:
			continue
		
		# Load item by ID
		var item_id = slot_data.get("item_id")
		var quantity = slot_data.get("quantity", 0)
		
		var item = _load_item_by_id(item_id)
		if item:
			add_item(item, quantity)


## Helper to load item by ID
func _load_item_by_id(item_id: String) -> Variant:
	# Try to load from Resources/Items directory
	var item_path = "res://Resources/Items/%s.tres" % item_id
	if ResourceLoader.exists(item_path):
		return load(item_path)
	
	# Try with other variations
	var apple_resource = load("res://Resources/Items/Apple.tres")
	if apple_resource and apple_resource.id == item_id:
		return apple_resource
	
	var ore_resource = load("res://Resources/Items/Ore.tres")
	if ore_resource and ore_resource.id == item_id:
		return ore_resource
	
	return null

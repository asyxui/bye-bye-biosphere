## InventoryDemo.gd
## Set up demo inventory items for showcase / testing
extends Node

func _ready() -> void:
	# Load some demo items
	var apple = load("res://Resources/Items/Apple.tres")
	var ore = load("res://Resources/Items/Ore.tres")
	
	# Add some items to inventory for demo
	var inv_manager = get_node_or_null("/root/InventoryManager")
	if inv_manager and apple:
		inv_manager.add_item(apple, 5)
	if inv_manager and ore:
		inv_manager.add_item(ore, 3)
	
	CustomLogger.log_info("Inventory demo initialized with sample items")

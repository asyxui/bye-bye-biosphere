## Headless smoke tests for deterministic logical conveyor movement.
extends "res://Tests/TestCase.gd"

const ORE := preload("res://Resources/Items/IronOre.tres")
const CONVEYOR_ITEM := preload("res://Resources/Items/Conveyor.tres")
const FIXED_STEP: float = 1.0 / 60.0

func _run() -> void:
	check(not ConveyorConnectionManager._segments_overlap(Vector3(10, 0, 0), Vector3(20, 0, 0), Vector3.ZERO, Vector3(10, 0, 0)))
	check(ConveyorConnectionManager._segments_overlap(Vector3(5, 0, 0), Vector3(15, 0, 0), Vector3.ZERO, Vector3(10, 0, 0)))
	check(ConveyorConnectionManager._segments_overlap(Vector3(10, 0, 0), Vector3(5, 0, 0), Vector3.ZERO, Vector3(10, 0, 0)))
	check(ConveyorConnectionManager._segments_overlap(Vector3(-5, 0, 0), Vector3(5, 0, 0), Vector3(0, 0, -5), Vector3(0, 0, 5)))

	_test_last_conveyor_keeps_connections()

	var belt := ConveyorBeltObject.new(Vector3.ZERO, Vector3(20, 0, 0))
	var source := ItemBuffer.new(1, 64)
	var source_stack := ItemStack.new(ORE, 2)
	check(source.insert_stack(source_stack) == 2)

	# The first item can be transferred, while the second remains at the source
	# until the belt has advanced enough to create start spacing.
	check(ItemTransfer.transfer(source, belt, ORE.id, 1) == 1)
	check(belt.items.size() == 1)
	check(source.get_extractable_quantity(ORE.id) == 1)
	check(belt.get_insertable_quantity(ItemStack.new(ORE, 1), 1) == 0)
	belt.advance_items(0.5)
	check(belt.get_insertable_quantity(ItemStack.new(ORE, 1), 1) == 1)

	# Ten logical items retain order and minimum spacing after movement.
	for index in range(9):
		var next_stack := ItemStack.new(ORE, 1)
		while belt.get_insertable_quantity(next_stack, 1) == 0:
			belt.advance_items(FIXED_STEP)
		check(belt.insert_stack(next_stack, 1) == 1)
	check(belt.items.size() == 10)
	belt.advance_items(2.0)
	for index in range(1, belt.items.size()):
		check(belt.items[index - 1].progress - belt.items[index].progress >= belt.get_spacing_progress() - 0.0001)

	# Extraction remains FIFO even when all items share the same item type.
	var extracted := belt.extract_stack(ORE.id, 1)
	check(extracted != null and extracted.quantity == 1)
	check(belt.items.size() == 9)

func _test_last_conveyor_keeps_connections() -> void:
	GameStateManager.set_creative_mode(false)
	ToolManager.clear_save_data()
	InventoryManager.clear_save_data()
	check(InventoryManager.add_item(CONVEYOR_ITEM, 1) == 0)
	check(ToolManager.equip_item(0, 0))
	ToolManager.set_selected_hotbar_slot(0, "item:%s" % CONVEYOR_ITEM.id)

	var port_root := Node3D.new()
	root.add_child(port_root)
	var start_port := ConnectionPoint.new()
	start_port.port_direction = ConnectionPoint.PortDirection.OUTPUT
	start_port.position = Vector3.ZERO
	port_root.add_child(start_port)
	var end_port := ConnectionPoint.new()
	end_port.port_direction = ConnectionPoint.PortDirection.INPUT
	end_port.position = Vector3(4, 0, 0)
	port_root.add_child(end_port)

	var tool := ConveyorTool.new()
	var placement_tool: ItemPlacementToolResource = ToolManager.get_tool_in_slot(0) as ItemPlacementToolResource
	tool.set_tool_resource(placement_tool)
	tool.on_activate(root)
	tool.waiting_for_second_press = true
	tool.first_port = start_port
	tool.start_pos = start_port.global_position
	ToolManager.active_tool_instance = tool
	tool._finalize_conveyor(end_port.global_position)

	var created_belt: ConveyorBeltObject = null
	for candidate in ConveyorConnectionManager.belts:
		var candidate_belt: ConveyorBeltObject = candidate as ConveyorBeltObject
		if candidate_belt != null and candidate_belt.start == start_port.global_position and candidate_belt.end == end_port.global_position:
			created_belt = candidate_belt
			break
	check(created_belt != null, "last-item placement should create a belt")
	check(created_belt != null and created_belt.start_port == start_port, "last-item placement should preserve the start connection")
	check(created_belt != null and created_belt.end_port == end_port, "last-item placement should preserve the end connection")

	if created_belt != null:
		ConveyorConnectionManager.remove_conveyor(created_belt, false, false)
	port_root.queue_free()
	ToolManager.clear_save_data()
	InventoryManager.clear_save_data()

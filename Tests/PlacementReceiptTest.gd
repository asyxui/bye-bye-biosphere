## Headless checks for the single placement refund contract.
extends "res://Tests/TestCase.gd"

const CONVEYOR_ID := "12"

func _run() -> void:
	var receipt := PlacementReceipt.create(CONVEYOR_ID, 1, true, false)
	check(PlacementReceipt.is_valid(receipt))
	check(PlacementReceipt.is_refundable(receipt))
	check(not PlacementReceipt.is_refundable(PlacementReceipt.create(CONVEYOR_ID, 1, false, true)))
	check(not PlacementReceipt.is_refundable(PlacementReceipt.create("", 0, false, true)))

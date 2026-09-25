class_name PlacementReceipt
extends RefCounted

const VERSION: int = 1

static func create(item_id: String, quantity: int, consumed: bool, was_creative: bool) -> Dictionary:
	return {
		"version": VERSION,
		"placement_item_id": item_id,
		"placement_quantity": maxi(0, quantity),
		"placement_consumed": consumed,
		"placement_was_creative": was_creative
	}

static func is_valid(receipt: Variant) -> bool:
	if not receipt is Dictionary:
		return false
	var data: Dictionary = receipt
	return int(data.get("version", 0)) == VERSION and data.has("placement_item_id") and data.has("placement_quantity") and data.has("placement_consumed") and data.has("placement_was_creative")

static func is_refundable(receipt: Variant) -> bool:
	if not is_valid(receipt):
		return false
	var data: Dictionary = receipt
	return bool(data.get("placement_consumed", false)) \
		and not bool(data.get("placement_was_creative", false)) \
		and not str(data.get("placement_item_id", "")).is_empty() \
		and int(data.get("placement_quantity", 0)) > 0

## Logical item on a conveyor segment. Its visual model is separate.
class_name ConveyorItem
extends ItemStack

@export_range(0.0, 1.0) var progress: float = 0.0

func _init(p_item: Variant = null, p_quantity: int = 0, p_progress: float = 0.0, p_metadata: Dictionary = {}) -> void:
	super(p_item, p_quantity, p_metadata)
	progress = clampf(p_progress, 0.0, 1.0)

func duplicate_stack() -> ConveyorItem:
	var copy := ConveyorItem.new(item_id, quantity, progress, metadata)
	copy.item_resource = item_resource
	return copy


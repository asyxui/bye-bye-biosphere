## Atomic logical transfer helper.
class_name ItemTransfer
extends RefCounted

## Moves up to quantity from source to destination.
## The source is extracted before destination insertion. Capacity is preflighted
## first, so a failed transfer leaves both owners unchanged.
static func transfer(source: ItemStorage, destination: ItemStorage, item_id: String, quantity: int) -> int:
	if source == null or destination == null or source == destination:
		return 0
	if item_id.is_empty() or quantity <= 0:
		return 0
	var source_preview := source.peek_stack(item_id)
	if source_preview == null:
		return 0
	var planned := mini(quantity, source.get_extractable_quantity(item_id))
	var probe := source_preview.duplicate_stack()
	probe.quantity = planned
	var accepted := destination.get_insertable_quantity(probe, planned)
	if accepted <= 0:
		return 0

	var extracted := source.extract_stack(item_id, accepted)
	if extracted == null or extracted.quantity <= 0:
		return 0
	var inserted := destination.insert_stack(extracted)
	if extracted.quantity > 0:
		# Restore a partial insertion to the source. The source just freed this
		# exact quantity, so this rollback is expected to be lossless.
		source.insert_stack(extracted)
	return inserted

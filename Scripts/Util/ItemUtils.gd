## ItemUtils.gd
extends Node

var _items_by_id: Dictionary = {}
var _items_index_initialized := false

func _ready() -> void:
	_ensure_item_index()

## Resolve item resources by their stable identifier. Resource filenames and
## display names are only an asset lookup detail.
func item_object_by_id(item_id: String) -> InventoryItem:
	_ensure_item_index()
	return _items_by_id.get(str(item_id), null) as InventoryItem

func _ensure_item_index() -> void:
	if _items_index_initialized:
		return
	_items_index_initialized = true

	var items_dir := DirAccess.open("res://Resources/Items")
	if items_dir == null:
		return

	items_dir.list_dir_begin()
	var filename := items_dir.get_next()
	while not filename.is_empty():
		if not items_dir.current_is_dir() and filename.ends_with(".tres"):
			var item = load("res://Resources/Items/%s" % filename)
			if item is InventoryItem:
				_items_by_id[str(item.id)] = item
		filename = items_dir.get_next()
	items_dir.list_dir_end()

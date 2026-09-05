## ItemUtils.gd
extends Node

var _items_by_id: Dictionary = {}
var _items_index_initialized := false

const ITEMS_PATH := "res://Resources/Items"

func _ready() -> void:
	_ensure_item_index()

## Resolve item resources by their stable identifier. Resource filenames and
## display names are only an asset lookup detail.
func item_object_by_id(item_id: String) -> InventoryItem:
	_ensure_item_index()
	return _items_by_id.get(str(item_id), null) as InventoryItem

func get_all_items() -> Array[InventoryItem]:
	_ensure_item_index()
	var items: Array[InventoryItem] = []
	for item_value in _items_by_id.values():
		var item := item_value as InventoryItem
		if item != null:
			items.append(item)
	items.sort_custom(func(a: InventoryItem, b: InventoryItem) -> bool:
		return a.id < b.id
	)
	return items

func _ensure_item_index() -> void:
	if _items_index_initialized:
		return
	_items_index_initialized = true

	for filename in ResourceLoader.list_directory(ITEMS_PATH):
		if not filename.ends_with(".tres"):
			continue
		var item = load(ITEMS_PATH.path_join(filename))
		if item is InventoryItem:
			_items_by_id[str(item.id)] = item

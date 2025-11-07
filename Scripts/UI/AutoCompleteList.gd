extends PanelContainer
class_name AutoCompleteList


@export var item_scene: PackedScene = preload("res://Scenes/UI/AutoCompleteItem.tscn")
var suggestions: Array[String] = []
var selected_index: int = 0

@onready var vbox: VBoxContainer = $VBoxContainer

signal suggestion_selected(suggestion: String)

func _ready():
	visible = false
	_clear_items()

## Show suggestions in the list. Optionally highlight based on current_text.
func show_suggestions(suggestion_list: Array[String], current_text: String = ""):
	suggestions = suggestion_list.duplicate()
	selected_index = 0
	_update_list(current_text)
	visible = suggestions.size() > 0

func _clear_items():
	for c in vbox.get_children():
		vbox.remove_child(c)
		c.queue_free()

## Update the list UI to match suggestions and selection
func _update_list(_current_text: String):
	_clear_items()
	for i in range(suggestions.size()):
		var item = item_scene.instantiate()
		vbox.add_child(item)
		if item.has_method("update"):
			item.update(suggestions[i], i == selected_index)
		item.connect("gui_input", Callable(self, "_on_item_gui_input").bind(i))

## Move selection up/down by delta
func move_selection(delta: int):
	if suggestions.is_empty():
		return
	selected_index = clamp(selected_index + delta, 0, suggestions.size() - 1)
	_update_list("")

## Get the currently selected suggestion
func get_selected() -> String:
	if suggestions.is_empty():
		return ""
	return suggestions[selected_index]

## Accept the currently selected suggestion
func accept_selected():
	if suggestions.is_empty():
		return
	emit_signal("suggestion_selected", suggestions[selected_index])
	hide_suggestions()

## Hide the suggestions list
func hide_suggestions():
	visible = false
	suggestions.clear()
	selected_index = 0
	_clear_items()

## Handle mouse click on an item
func _on_item_gui_input(event: InputEvent, idx: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected_index = idx
		accept_selected()

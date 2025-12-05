## Slot selection menu for saving/loading games
extends Control

class_name SlotSelectionMenu

@onready var slot_list = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer
@onready var title_label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var back_button = $PanelContainer/MarginContainer/VBoxContainer/BackButton
@onready var input_container = $PanelContainer/MarginContainer/VBoxContainer/InputContainer
@onready var text_input = $PanelContainer/MarginContainer/VBoxContainer/InputContainer/TextInput
@onready var save_name_button = $PanelContainer/MarginContainer/VBoxContainer/InputContainer/SaveNameButton

signal slot_selected(slot_id: String)
signal back_pressed

var is_save_mode: bool = false
var slot_manager


func _ready() -> void:
	var SaveSlotManagerClass = load("res://Scripts/Managers/SaveSlotManager.gd")
	slot_manager = SaveSlotManagerClass.new()
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if text_input:
		text_input.text_submitted.connect(_on_save_name_submitted)
	if save_name_button:
		save_name_button.pressed.connect(_on_save_name_submitted.bindv([""]))
	
	hide()


## Open the menu for saving
func open_for_save() -> void:
	is_save_mode = true
	title_label.text = "Save Game"
	input_container.show()
	text_input.text = ""
	text_input.grab_focus()
	_refresh_slots()
	show()


## Open the menu for loading
func open_for_load() -> void:
	is_save_mode = false
	title_label.text = "Load Game"
	input_container.hide()
	_refresh_slots()
	show()


## Refresh slot list display
func _refresh_slots() -> void:
	# Clear existing buttons
	for child in slot_list.get_children():
		child.queue_free()
	
	var slots = slot_manager.get_save_slots()
	
	# Show existing slots
	for slot in slots:
		var slot_id = slot["id"]
		var timestamp = slot["timestamp"]
		var time_str = ""
		
		if timestamp > 0:
			var datetime = Time.get_datetime_dict_from_system()
			time_str = " - %04d-%02d-%02d" % [datetime["year"], datetime["month"], datetime["day"]]
		
		_add_slot_button(slot_id + time_str, slot_id)


## Add a slot button to the list
func _add_slot_button(display_name: String, slot_id: String) -> void:
	var button = Button.new()
	button.text = display_name
	button.custom_minimum_size = Vector2(200, 40)
	button.pressed.connect(func():
		slot_selected.emit(slot_id)
		hide()
	)
	slot_list.add_child(button)


## Handle save name submission
func _on_save_name_submitted(_text: String = "") -> void:
	var slot_name = text_input.text.strip_edges()
	if slot_name.is_empty():
		slot_name = "world_%d" % (Time.get_ticks_msec() % 10000)
	
	slot_selected.emit(slot_name)
	hide()


## Handle back button
func _on_back_pressed() -> void:
	back_pressed.emit()
	hide()

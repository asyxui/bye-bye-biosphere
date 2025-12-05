## Save/Load menu UI
extends Control

class_name SaveLoadMenu

@onready var save_button = $VBoxContainer/SaveButton
@onready var load_button = $VBoxContainer/LoadButton
@onready var back_button = $VBoxContainer/BackButton

signal save_requested
signal load_requested
signal back_pressed


func _ready() -> void:
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if load_button:
		load_button.pressed.connect(_on_load_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)


func _on_save_pressed() -> void:
	save_requested.emit()


func _on_load_pressed() -> void:
	load_requested.emit()


func _on_back_pressed() -> void:
	back_pressed.emit()

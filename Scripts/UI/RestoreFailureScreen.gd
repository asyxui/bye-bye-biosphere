extends Control

class_name RestoreFailureScreen

signal choose_world
signal reset_world

@onready var message_label: Label = $PanelContainer/MarginContainer/VBoxContainer/MessageLabel
@onready var reset_world_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ResetWorldButton
@onready var choose_world_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ChooseWorldButton
@onready var quit_button: Button = $PanelContainer/MarginContainer/VBoxContainer/QuitButton


func _ready() -> void:
	reset_world_button.pressed.connect(func():
		reset_world_button.disabled = true
		reset_world.emit()
	)
	choose_world_button.pressed.connect(func(): choose_world.emit())
	quit_button.pressed.connect(func(): get_tree().quit())
	hide()


func show_error(error: String, can_reset_world := true) -> void:
	if error == SaveManager.INCOMPATIBLE_SAVE_MESSAGE:
		message_label.text = "This world was saved with a different prototype version and can't be loaded. Reset it to erase its saved progress and start fresh, or load another world."
	else:
		message_label.text = "The world couldn't be loaded.\n%s" % error
	reset_world_button.visible = can_reset_world
	reset_world_button.disabled = false
	show()
	(reset_world_button if can_reset_world else choose_world_button).grab_focus()

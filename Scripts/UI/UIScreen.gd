class_name UIScreen
extends Control

## Lightweight configuration shared by screens managed by UIManager.
@export var screen_id: int = -1
@export var channel: int = 0
@export var blocks_gameplay: bool = true
@export var pauses_tree: bool = false
@export var dismissible: bool = true
@export var initial_focus_path: NodePath

func present(_data: Dictionary = {}) -> void:
	show()
	call_deferred("focus_initial_control")

func dismiss() -> void:
	hide()

func focus_initial_control() -> void:
	if initial_focus_path != NodePath():
		var control := get_node_or_null(initial_focus_path) as Control
		if control:
			control.grab_focus()

extends "res://Tests/TestCase.gd"

func _run() -> void:
	var original_stack: Array[int] = UIManager._stack.duplicate()
	var original_focus_stack: Array[Control] = UIManager._focus_stack.duplicate()
	var original_screens: Dictionary = UIManager._screens.duplicate()
	var was_paused := root.get_tree().paused
	var console := Control.new()
	var input_line := LineEdit.new()
	root.add_child(console)
	console.add_child(input_line)
	UIManager._screens[UIManager.ScreenId.CONSOLE] = console
	UIManager._stack.clear()
	UIManager._focus_stack.clear()

	for overlay_id in [UIManager.ScreenId.INVENTORY, UIManager.ScreenId.JOURNAL, UIManager.ScreenId.CONSOLE]:
		UIManager._stack.assign([overlay_id])
		UIManager._apply_context()
		check(not root.get_tree().paused)
	UIManager._stack.clear()
	UIManager._apply_context()

	var open_console_key := InputEventKey.new()
	open_console_key.keycode = KEY_K
	open_console_key.pressed = true
	UIManager._input(open_console_key)
	check(UIManager.is_open(UIManager.ScreenId.CONSOLE))
	check(input_line.has_focus())
	check(not root.get_tree().paused)
	var console_text_key := InputEventKey.new()
	console_text_key.keycode = KEY_K
	console_text_key.pressed = true
	UIManager._input(console_text_key)
	check(UIManager.is_open(UIManager.ScreenId.CONSOLE))

	var escape_key := InputEventKey.new()
	escape_key.keycode = KEY_ESCAPE
	escape_key.pressed = true
	UIManager._input(escape_key)
	check(not UIManager.is_open(UIManager.ScreenId.CONSOLE))
	check(not input_line.has_focus())
	check(not root.get_tree().paused)

	UIManager._stack.assign([UIManager.ScreenId.PAUSE])
	UIManager._apply_context()
	check(root.get_tree().paused)
	UIManager._stack.clear()
	UIManager._apply_context()
	check(not root.get_tree().paused)

	UIManager._stack.assign(original_stack)
	UIManager._focus_stack.assign(original_focus_stack)
	UIManager._screens = original_screens
	root.get_tree().paused = was_paused
	console.queue_free()

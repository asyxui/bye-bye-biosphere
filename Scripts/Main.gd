extends Node


func _ready() -> void:
	CustomLogger.log_info("Starting Bye Bye Biosphere!")

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_tool_wheel"):
		var hud = get_node_or_null("Hud")
		if hud:
			var tool_wheel = hud.get_node_or_null("ToolPickerWheel")
			if tool_wheel:
				# Open wheel for currently selected slot
				var action_bar = hud.get_node_or_null("ActionBar")
				if action_bar:
					tool_wheel.open_wheel(action_bar.current_slot)
					get_viewport().set_input_as_handled()

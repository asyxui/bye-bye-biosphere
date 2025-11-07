class_name CustomLogger

# Custom logging functions that will show in both console and debug console
static func log(message: String) -> void:
	print(message)
	DebugConsole.print_to_console(str(message))

static func log_warn(message: String) -> void:
	print("WARNING: ", message)
	DebugConsole.print_to_console("[color=orange]WARNING: " + str(message) + "[/color]")

static func log_error(message: String) -> void:
	push_error(message)
	DebugConsole.print_to_console("[color=red]ERROR: " + str(message) + "[/color]")

static func log_info(message: String) -> void:
	print("INFO: ", message)
	DebugConsole.print_to_console("[color=cyan]INFO: " + str(message) + "[/color]")

static func log_success(message: String) -> void:
	print("SUCCESS: ", message)
	DebugConsole.print_to_console("[color=lime]SUCCESS: " + str(message) + "[/color]")

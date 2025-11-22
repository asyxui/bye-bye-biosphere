extends CanvasLayer
class_name DebugConsole

@onready var console_panel: Panel = $ConsolePanel
@onready var output_log: RichTextLabel = $ConsolePanel/VBoxContainer/OutputLog

@onready var input_line: LineEdit = $ConsolePanel/VBoxContainer/InputLine
@onready var autocomplete_list: AutoCompleteList = $ConsolePanel/AutoCompleteList
var autocomplete_script := preload("res://Scripts/UI/AutoCompleteList.gd")


var is_console_open: bool = false
var command_history: Array[String] = []
var history_index: int = -1
var max_history: int = 50
var max_log_lines: int = 500

var commands: Dictionary = {}
var autocomplete_active: bool = false


# Static instance for singleton pattern
static var instance: DebugConsole = null
# Static log buffer for early log messages
static var _log_buffer: Array = []
static var _max_buffer_size: int = 100

func _ready() -> void:
	# Enable input processing
	set_process_input(true)
	
	# Register this instance as the singleton
	DebugConsole.instance = self

	# Start hidden
	console_panel.visible = false
	
	# Connect signals
	input_line.text_submitted.connect(_on_input_submitted)
	autocomplete_list.suggestion_selected.connect(_on_autocomplete_selected)
	input_line.text_changed.connect(_on_input_text_changed)
	
	# Connect to GameStateManager signals
	GameStateManager.console_opened.connect(_on_console_opened)
	GameStateManager.console_closed.connect(_on_console_closed)
	
	# Register commands
	register_command("help", "Display all available commands", _cmd_help)
	register_command("clear", "Clear the console output", _cmd_clear)
	register_command("quit", "Quit the game", _cmd_quit)
	register_command("history", "Show command history", _cmd_history)
	register_command("echo", "Echo text to console. Usage: echo <text>", _cmd_echo)
	
	# Log welcome message
	log_message("[color=cyan]Debug Console initialized. Type 'help' for available commands.[/color]")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_K:
			GameStateManager.toggle_console()
			get_viewport().set_input_as_handled()
		elif GameStateManager.is_console_open:
			# Handle up/down for command history
			if event.keycode == KEY_UP:
				if autocomplete_active:
					autocomplete_list.move_selection(-1)
					get_viewport().set_input_as_handled()
				else:
					navigate_history(-1)
					get_viewport().set_input_as_handled()
			elif event.keycode == KEY_DOWN:
				if autocomplete_active:
					autocomplete_list.move_selection(1)
					get_viewport().set_input_as_handled()
				else:
					navigate_history(1)
					get_viewport().set_input_as_handled()
			elif event.keycode == KEY_TAB:
				if autocomplete_active:
					autocomplete_list.accept_selected()
					get_viewport().set_input_as_handled()

func toggle_console() -> void:
	is_console_open = !is_console_open
	_update_console_ui()

func _update_console_ui() -> void:
	console_panel.visible = is_console_open
	
	if is_console_open:
		input_line.grab_focus()
		input_line.clear()
		history_index = -1
		autocomplete_list.hide_suggestions()
		autocomplete_active = false
	else:
		input_line.release_focus()

func _on_console_opened():
	is_console_open = true
	_update_console_ui()

func _on_console_closed():
	is_console_open = false
	_update_console_ui()

func _on_input_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	
	# Add to history
	if command_history.is_empty() or command_history[0] != text:
		command_history.push_front(text)
		if command_history.size() > max_history:
			command_history.pop_back()
	
	history_index = -1
	
	# Echo the command
	log_message("[color=yellow]> " + text + "[/color]")
	
	# Execute the command
	execute_command(text)
	
	# Clear input
	input_line.clear()
	autocomplete_list.hide_suggestions()
	autocomplete_active = false

func _on_input_text_changed(new_text: String) -> void:
	if new_text.strip_edges().is_empty():
		autocomplete_list.hide_suggestions()
		autocomplete_active = false
		return
	var prefix = new_text.split(" ")[0].to_lower()
	var matches: Array[String] = []
	for cmd in commands.keys():
		if cmd.begins_with(prefix):
			matches.append(cmd)
	if matches.size() > 0:
		autocomplete_list.show_suggestions(matches, prefix)
		autocomplete_active = true
	else:
		autocomplete_list.hide_suggestions()
		autocomplete_active = false

func _on_autocomplete_selected(suggestion: String) -> void:
	# Fill the input line with the selected suggestion, preserving any arguments typed
	var current_text = input_line.text
	var parts = current_text.split(" ", false)
	if parts.size() > 1:
		input_line.text = suggestion + " " + " ".join(parts.slice(1))
	else:
		input_line.text = suggestion + " "
	input_line.caret_column = input_line.text.length()
	autocomplete_list.hide_suggestions()
	autocomplete_active = false

func navigate_history(direction: int) -> void:
	if command_history.is_empty():
		return
	
	history_index = clampi(history_index + direction, -1, command_history.size() - 1)
	
	if history_index == -1:
		input_line.text = ""
	else:
		input_line.text = command_history[history_index]
	
	# Move cursor to end
	input_line.caret_column = input_line.text.length()

func execute_command(cmd_text: String) -> void:
	var parts = cmd_text.strip_edges().split(" ", false)
	if parts.is_empty():
		return
	
	var cmd_name = parts[0].to_lower()
	var args = parts.slice(1)
	
	if cmd_name in commands:
		var cmd_data = commands[cmd_name]
		var callback: Callable = cmd_data["callback"]
		callback.call(args)
	else:
		log_message("[color=red]Unknown command: '" + cmd_name + "'. Type 'help' for available commands.[/color]")

func register_command(cmd_name: String, description: String, callback: Callable) -> void:
	commands[cmd_name.to_lower()] = {
		"description": description,
		"callback": callback
	}

func log_message(message: String) -> void:
	output_log.append_text(message + "\n")
	
	# Limit log lines to prevent memory issues
	var line_count = output_log.get_line_count()
	if line_count > max_log_lines:
		# Get all text and remove oldest lines
		var text = output_log.text
		var lines = text.split("\n")
		var keep_lines = lines.slice(line_count - max_log_lines)
		output_log.clear()
		output_log.append_text("\n".join(keep_lines))
	
	# Scroll to bottom
	output_log.scroll_to_line(output_log.get_line_count() - 1)


# Static method to receive log messages from anywhere
static func print_to_console(message: String) -> void:
	if DebugConsole.instance:
		DebugConsole.instance.log_message(message)
	else:
		# Buffer the message
		if DebugConsole._log_buffer.size() >= DebugConsole._max_buffer_size:
			DebugConsole._log_buffer.pop_front()
		DebugConsole._log_buffer.push_back(message)


# Static method to flush buffer when console is ready
static func _flush_log_buffer() -> void:
	if DebugConsole.instance:
		for msg in DebugConsole._log_buffer:
			DebugConsole.instance.log_message(msg)
		DebugConsole._log_buffer.clear()

# Built-in command implementations
func _cmd_help(_args: Array) -> void:
	log_message("[color=cyan]=== Available Commands ===[/color]")
	var cmd_names = commands.keys()
	cmd_names.sort()
	for cmd_name in cmd_names:
		var cmd_data = commands[cmd_name]
		log_message("[color=lime]" + cmd_name + "[/color] - " + cmd_data["description"])

func _cmd_clear(_args: Array) -> void:
	output_log.clear()

func _cmd_quit(_args: Array) -> void:
	log_message("[color=orange]Quitting game...[/color]")
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()

func _cmd_history(_args: Array) -> void:
	if command_history.is_empty():
		log_message("[color=gray]No command history.[/color]")
		return
	
	log_message("[color=cyan]=== Command History ===[/color]")
	for i in range(command_history.size()):
		log_message(str(i + 1) + ". " + command_history[i])

func _cmd_echo(args: Array) -> void:
	if args.is_empty():
		log_message("[color=gray]Usage: echo <text>[/color]")
	else:
		log_message(" ".join(args))

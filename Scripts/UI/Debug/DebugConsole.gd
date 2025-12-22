extends Control
class_name DebugConsole

@onready var console_panel: Panel = $ConsolePanel
@onready var output_log: RichTextLabel = $ConsolePanel/VBoxContainer/OutputLog

@onready var input_line: LineEdit = $ConsolePanel/VBoxContainer/InputLine
@onready var autocomplete_list: AutoCompleteList = $ConsolePanel/AutoCompleteList
@onready var close_button: Button = $ConsolePanel/VBoxContainer/TitleBar/CloseButton
var autocomplete_script := preload("res://Scripts/UI/AutoCompleteList.gd")


var is_console_open: bool = false
var command_history: Array[String] = []
var history_index: int = -1
var max_history: int = 50
var max_log_lines: int = 500

var commands: Dictionary = {}
var autocomplete_active: bool = false
var save_game_manager: Node = null


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
	visible = false
	console_panel.visible = false
	
	# Connect signals
	input_line.text_submitted.connect(_on_input_submitted)
	autocomplete_list.suggestion_selected.connect(_on_autocomplete_selected)
	input_line.text_changed.connect(_on_input_text_changed)
	visibility_changed.connect(_on_visibility_changed)
	# close_button.pressed signal is already connected in the scene editor
	
	# Register commands
	register_command("help", "Display all available commands", _cmd_help)
	register_command("clear", "Clear the console output", _cmd_clear)
	register_command("save", "Save the current game. Usage: save [slot_name]", _cmd_save)
	register_command("load", "Load a save game. Usage: load <slot_name>", _cmd_load)
	register_command("quit", "Quit the game", _cmd_quit)
	register_command("history", "Show command history", _cmd_history)
	register_command("echo", "Echo text to console. Usage: echo <text>", _cmd_echo)
	register_command("savegame", "Display current save game information", _cmd_savegame)
	register_command("fps", "Display FPS information", _cmd_fps)
	
	# Get the save game manager from Main (same way MenuManager does it)
	var main_node = get_tree().root.find_child("Main", true, false)
	if main_node and main_node.has_meta("save_game_manager"):
		save_game_manager = main_node.get_meta("save_game_manager")
	else:
		# Fallback: create our own if Main doesn't have one
		save_game_manager = load("res://Scripts/Managers/SaveGameManager.gd").new()
		add_child(save_game_manager)
	
	# Log welcome message
	log_message("[color=cyan]Debug Console ready. Type 'help' for commands.[/color]")


func _get_save_slot_id(args: Array) -> String:
	if not args.is_empty():
		return args[0]
	
	var root = get_tree().root
	if root.has_meta("current_save_slot"):
		return root.get_meta("current_save_slot")
	
	return "default"


func _save_and_quit() -> void:
	var slot_id = _get_save_slot_id([])
	if save_game_manager:
		save_game_manager.save_completed.connect(func(success, error):
			if not success:
				log_message("[color=orange]Save failed: %s[/color]" % error)
			get_tree().quit()
		, CONNECT_ONE_SHOT)
		save_game_manager.save_game(slot_id)
	else:
		get_tree().quit()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		# Handle Escape to close console
		if event.keycode == KEY_ESCAPE:
			GameStateManager.close_console()
			get_viewport().set_input_as_handled()
			return
		# Handle Tab for autocomplete
		elif event.keycode == KEY_TAB and input_line.has_focus() and autocomplete_active:
			autocomplete_list.accept_selected()
			get_viewport().set_input_as_handled()
			return
	
	# Block scroll wheel events from reaching ActionBar when console is visible
	if event is InputEventMouseButton:
		if (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN) and event.pressed:
			get_viewport().set_input_as_handled()

func toggle_console() -> void:
	is_console_open = !is_console_open
	_update_console_ui()

func _update_console_ui() -> void:
	is_console_open = visible
	console_panel.visible = is_console_open
	
	if is_console_open:
		input_line.grab_focus()
		input_line.clear()
		history_index = -1
		autocomplete_list.hide_suggestions()
		autocomplete_active = false
	else:
		input_line.release_focus()

func _on_visibility_changed() -> void:
	_update_console_ui()

func _on_close_button_pressed() -> void:
	HUDManager.toggle_debug_console()

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
	_save_and_quit()

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

func _cmd_save(args: Array) -> void:
	var slot_id = _get_save_slot_id(args)
	log_message("[color=cyan]Saving to slot: %s...[/color]" % slot_id)
	
	if save_game_manager:
		save_game_manager.save_completed.connect(func(success, error):
			if success:
				log_message("[color=green]Save completed: %s[/color]" % slot_id)
			else:
				log_message("[color=red]Save failed: %s[/color]" % error)
		, CONNECT_ONE_SHOT)
		save_game_manager.save_game(slot_id)
	else:
		log_message("[color=red]SaveGameManager not found[/color]")

func _cmd_load(args: Array) -> void:
	if args.is_empty():
		log_message("[color=gray]Usage: load <slot_name>[/color]")
		return
	
	var slot_id = args[0]
	log_message("[color=cyan]Loading slot: %s...[/color]" % slot_id)
	
	if save_game_manager:
		GameStateManager.close_console()
		save_game_manager.save_completed.connect(func(success, error):
			if not success:
				log_message("[color=red]Load failed: %s[/color]" % error)
		, CONNECT_ONE_SHOT)
		save_game_manager.load_game(slot_id)
	else:
		log_message("[color=red]SaveGameManager not found[/color]")

func _cmd_savegame(_args: Array) -> void:
	# Get current save slot
	var slot_id = "default"
	var root = get_tree().root
	if root.has_meta("current_save_slot"):
		slot_id = root.get_meta("current_save_slot")
	
	log_message("[color=cyan]=== Save Game Information ===[/color]")
	log_message("[color=yellow]Current Slot ID:[/color] %s" % slot_id)
	
	# Get save slot path
	var slot_path = "user://saves".path_join(slot_id)
	var absolute_slot_path = ProjectSettings.globalize_path(slot_path)
	
	log_message("[color=yellow]Save Directory:[/color] %s" % absolute_slot_path)
	
	if not DirAccess.dir_exists_absolute(slot_path):
		log_message("[color=orange]Warning: Save slot directory does not exist yet[/color]")
		return
	
	# Get metadata
	var SaveDataManagerClass = load("res://Scripts/Managers/SaveDataManager.gd")
	var data_manager = SaveDataManagerClass.new(slot_path)
	var metadata = data_manager.get_metadata()
	
	if metadata.is_empty():
		log_message("[color=red]No metadata found![/color]")
		return
	
	# Display metadata info
	log_message("[color=yellow]Version:[/color] %s" % metadata.get("version", "unknown"))
	
	# Convert timestamp to readable format
	var timestamp_ms = metadata.get("timestamp", 0)
	if timestamp_ms > 0:
		var timestamp_sec = timestamp_ms / 1000
		var datetime = Time.get_datetime_dict_from_unix_time(timestamp_sec)
		var time_str = "%04d-%02d-%02d %02d:%02d:%02d" % [
			datetime.year, datetime.month, datetime.day,
			datetime.hour, datetime.minute, datetime.second
		]
		log_message("[color=yellow]Last Save:[/color] %s" % time_str)
	else:
		log_message("[color=yellow]Last Save:[/color] Never")
	
	# Player position
	var player_pos = metadata.get("player_position", {})
	if not player_pos.is_empty():
		log_message("[color=yellow]Player Position:[/color] (%.1f, %.1f, %.1f)" % [
			player_pos.get("x", 0.0),
			player_pos.get("y", 0.0),
			player_pos.get("z", 0.0)
		])
	
	# Inventory info
	var inventory = data_manager.get_inventory()
	log_message("[color=yellow]Inventory Slots:[/color] %d" % inventory.size())
	
	# Hotbar info
	var hotbar = data_manager.get_hotbar()
	log_message("[color=yellow]Hotbar Slots:[/color] %d" % hotbar.size())
	
	# World database size
	var voxel_db_path = absolute_slot_path.path_join("world.sqlite")
	if FileAccess.file_exists(voxel_db_path):
		var file = FileAccess.open(voxel_db_path, FileAccess.READ)
		if file:
			var file_size_bytes = file.get_length()
			var file_size_mb = file_size_bytes / (1024.0 * 1024.0)
			log_message("[color=yellow]World Database:[/color] %.2f MB (%d bytes)" % [file_size_mb, file_size_bytes])
	else:
		log_message("[color=yellow]World Database:[/color] Not found")
	
	log_message("[color=cyan]============================[/color]")

func _cmd_fps(_args: Array) -> void:
	HUDManager.toggle_fps_label()

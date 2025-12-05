extends CanvasLayer

@onready var pause_menu = $PauseMenu
@onready var settings_menu = $SettingsMenu
@onready var slot_selection_menu = $SlotSelectionMenu if has_node("SlotSelectionMenu") else null
@onready var loading_screen = $LoadingScreen if has_node("LoadingScreen") else null

var save_game_manager: Node
var current_save_slot: String = "default"


func _ready():
	# Enable input processing
	set_process_input(true)
	
	# Update current_save_slot from root meta if it was set during startup
	var root = get_tree().root
	if root.has_meta("current_save_slot"):
		current_save_slot = root.get_meta("current_save_slot")
	else:
		# Also check VoxelStreamManager for the current slot
		var voxel_stream_manager = get_node_or_null("/root/VoxelStreamManager")
		if voxel_stream_manager:
			current_save_slot = voxel_stream_manager.get_current_slot()
	
	# Hide menus initially
	pause_menu.hide()
	settings_menu.hide()
	if slot_selection_menu:
		slot_selection_menu.hide()
	
	# Connect signals
	connect_pause_menu_signals()
	connect_settings_menu_signals()
	
	# Connect slot selection menu signals if they exist
	if slot_selection_menu:
		slot_selection_menu.slot_selected.connect(_on_slot_selected)
		slot_selection_menu.back_pressed.connect(_on_slot_selection_back)
	
	# Connect to GameStateManager signals
	GameStateManager.menu_opened.connect(_on_menu_opened)
	GameStateManager.menu_closed.connect(_on_menu_closed)
	
	# Get the save game manager from Main
	var main_node = get_tree().root.find_child("Main", true, false)
	if main_node and main_node.has_meta("save_game_manager"):
		save_game_manager = main_node.get_meta("save_game_manager")
	else:
		# Fallback: create our own if Main doesn't have one
		save_game_manager = load("res://Scripts/Managers/SaveGameManager.gd").new()
		add_child(save_game_manager)
	
	if save_game_manager:
		save_game_manager.save_completed.connect(_on_save_completed)

func _input(event: InputEvent) -> void:
	# If menu is open, allow ESC to close it
	if GameStateManager.is_menu_open and event.is_action_pressed("menu"):
		GameStateManager.close_menu()
		get_viewport().set_input_as_handled()

func _on_menu_opened():
	pause_menu.show()
	settings_menu.hide()

func _on_menu_closed():
	pause_menu.hide()
	settings_menu.hide()

func open_settings():
	pause_menu.hide()
	settings_menu.show()

func close_settings():
	settings_menu.hide()
	pause_menu.show()

func connect_pause_menu_signals():
	pause_menu.get_node("Panel/MarginContainer/VBoxContainer/ResumeButton").pressed.connect(_on_resume_pressed)
	pause_menu.get_node("Panel/MarginContainer/VBoxContainer/SaveButton").pressed.connect(_on_save_pressed)
	pause_menu.get_node("Panel/MarginContainer/VBoxContainer/LoadButton").pressed.connect(_on_load_pressed)
	pause_menu.get_node("Panel/MarginContainer/VBoxContainer/ResetButton").pressed.connect(_on_reset_pressed)
	pause_menu.get_node("Panel/MarginContainer/VBoxContainer/SettingsButton").pressed.connect(_on_settings_pressed)
	pause_menu.get_node("Panel/MarginContainer/VBoxContainer/QuitButton").pressed.connect(_on_quit_pressed)

func connect_settings_menu_signals():
	settings_menu.get_node("Panel/MarginContainer/VBoxContainer/ButtonContainer/BackButton").pressed.connect(_on_back_pressed)

func _on_resume_pressed():
	GameStateManager.close_menu()

func _on_settings_pressed():
	open_settings()

func _on_save_pressed():
	if slot_selection_menu:
		pause_menu.hide()
		slot_selection_menu.open_for_save()
		slot_selection_menu.show()

func _on_load_pressed():
	if slot_selection_menu:
		pause_menu.hide()
		slot_selection_menu.open_for_load()
		slot_selection_menu.show()

func _on_reset_pressed():
	# Reset the current world to empty state
	var slot_id = current_save_slot
	CustomLogger.log_info("Resetting world: %s" % slot_id)
	
	if loading_screen:
		# Step 1: Show loading screen and lock player
		_start_loading("Resetting World...")
		
		# Step 2: Close menu
		GameStateManager.close_menu()
		
		# Step 3: Perform reset via VoxelStreamManager
		var voxel_stream_manager = get_node("/root/VoxelStreamManager")
		if voxel_stream_manager:
			voxel_stream_manager.reset_world_async()
			
			# Wait for reset to complete
			var reset_result = await voxel_stream_manager.reset_complete
			if reset_result[0]:  # reset_result[0] is success bool
				# Step 4: Reload scene to show fresh world
				get_tree().reload_current_scene()
			else:
				CustomLogger.log_error("Reset failed: %s" % reset_result[1])
				_finish_loading()
		else:
			push_error("VoxelStreamManager not found")
			_finish_loading()
	else:
		push_error("LoadingScreen not found")

func _on_quit_pressed():
	var slot_id = current_save_slot
	var root = get_tree().root
	if root.has_meta("current_save_slot"):
		slot_id = root.get_meta("current_save_slot")
	
	if save_game_manager:
		save_game_manager.save_completed.connect(func(success, error):
			if not success:
				push_error("Failed to save before quit: %s" % error)
			get_tree().quit()
		)
		save_game_manager.save_game(slot_id)
	else:
		push_error("SaveGameManager not available")
		get_tree().quit()

func _on_back_pressed():
	close_settings()


## Handle slot selected
func _on_slot_selected(slot_id: String) -> void:
	current_save_slot = slot_id
	var slot_path = "user://saves".path_join(slot_id)
	var is_load = DirAccess.dir_exists_absolute(slot_path) and not slot_selection_menu.is_save_mode
	
	if is_load:
		if loading_screen and save_game_manager:
			_start_loading("Loading World...")
			GameStateManager.close_menu()
			save_game_manager.load_game(slot_id)
	else:
		if save_game_manager:
			save_game_manager.save_game(slot_id)
			pause_menu.show()
			if slot_selection_menu:
				slot_selection_menu.hide()


## Handle back from slot selection
func _on_slot_selection_back() -> void:
	pause_menu.show()
	if slot_selection_menu:
		slot_selection_menu.hide()


## Handle save completion
func _on_save_completed(success: bool, error_message: String) -> void:
	if success:
		# Use the root meta as source of truth for current slot
		var slot_id = current_save_slot
		var tree = get_tree()
		if tree and tree.root and tree.root.has_meta("current_save_slot"):
			slot_id = tree.root.get_meta("current_save_slot")
		CustomLogger.log_info("Game saved to slot: %s" % slot_id)
	else:
		push_error("Failed to save game: %s" % error_message)


## Start loading sequence - show loading screen and lock player input
func _start_loading(operation_name: String) -> void:
	if loading_screen:
		loading_screen.show_loading(operation_name)
	GameStateManager.start_loading()


## Finish loading sequence - hide loading screen and unlock player input
func _finish_loading() -> void:
	GameStateManager.finish_loading()
	if loading_screen:
		loading_screen.hide_loading()


## Hide the loading screen (deprecated - use _finish_loading instead)
func hide_loading_screen() -> void:
	if loading_screen:
		loading_screen.hide_loading()

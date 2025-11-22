extends CanvasLayer

@onready var pause_menu = $PauseMenu
@onready var settings_menu = $SettingsMenu

func _ready():
	# Enable input processing
	set_process_input(true)
	
	# Hide menus initially
	pause_menu.hide()
	settings_menu.hide()
	
	# Connect signals
	connect_pause_menu_signals()
	connect_settings_menu_signals()
	
	# Connect to GameStateManager signals
	GameStateManager.menu_opened.connect(_on_menu_opened)
	GameStateManager.menu_closed.connect(_on_menu_closed)

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
	pause_menu.get_node("Panel/MarginContainer/VBoxContainer/SettingsButton").pressed.connect(_on_settings_pressed)
	pause_menu.get_node("Panel/MarginContainer/VBoxContainer/QuitButton").pressed.connect(_on_quit_pressed)

func connect_settings_menu_signals():
	settings_menu.get_node("Panel/MarginContainer/VBoxContainer/ButtonContainer/BackButton").pressed.connect(_on_back_pressed)

func _on_resume_pressed():
	GameStateManager.close_menu()

func _on_settings_pressed():
	open_settings()

func _on_quit_pressed():
	get_tree().quit()

func _on_back_pressed():
	close_settings()

extends CanvasLayer

@onready var pause_menu = $PauseMenu
@onready var settings_menu = $SettingsMenu

var is_paused = false

func _ready():
	# Hide menus initially
	pause_menu.hide()
	settings_menu.hide()
	
	# Connect signals
	connect_pause_menu_signals()
	connect_settings_menu_signals()

func _input(event):
	if event.is_action_pressed("menu"):
		toggle_pause()

func toggle_pause():
	is_paused = !is_paused
	
	if is_paused:
		open_pause_menu()
	else:
		close_all_menus()

func open_pause_menu():
	pause_menu.show()
	settings_menu.hide()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_all_menus():
	pause_menu.hide()
	settings_menu.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	is_paused = false

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
	toggle_pause()

func _on_settings_pressed():
	open_settings()

func _on_quit_pressed():
	get_tree().quit()

func _on_back_pressed():
	close_settings()

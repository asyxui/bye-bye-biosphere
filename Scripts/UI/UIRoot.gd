extends CanvasLayer

@onready var inventory = $InventoryUI
@onready var console = $DebugConsole
@onready var tool_wheel = $ToolPickerWheel
@onready var pause_menu = $PauseMenu
@onready var settings_menu = $SettingsMenu
@onready var save_load_menu = $SlotSelectionMenu
@onready var loading_screen = $LoadingScreen
@onready var action_bar = $HUD/ActionBar

func _ready() -> void:
	UIManager.register_root(self)
	_connect_navigation()

func get_screens() -> Dictionary:
	return {
		UIManager.ScreenId.INVENTORY: inventory,
		UIManager.ScreenId.CONSOLE: console,
		UIManager.ScreenId.TOOL_WHEEL: tool_wheel,
		UIManager.ScreenId.PAUSE: pause_menu,
		UIManager.ScreenId.SETTINGS: settings_menu,
		UIManager.ScreenId.SAVE_LOAD: save_load_menu,
		UIManager.ScreenId.LOADING: loading_screen,
	}

func get_action_bar() -> Control:
	return action_bar

func _connect_navigation() -> void:
	pause_menu.get_node("Panel/MarginContainer/VBoxContainer/ResumeButton").pressed.connect(UIManager.pop)
	pause_menu.get_node("Panel/MarginContainer/VBoxContainer/SettingsButton").pressed.connect(func(): UIManager.push(UIManager.ScreenId.SETTINGS))
	pause_menu.get_node("Panel/MarginContainer/VBoxContainer/SaveButton").pressed.connect(func(): UIManager.push(UIManager.ScreenId.SAVE_LOAD, {"save": true}))
	pause_menu.get_node("Panel/MarginContainer/VBoxContainer/LoadButton").pressed.connect(func(): UIManager.push(UIManager.ScreenId.SAVE_LOAD))
	pause_menu.get_node("Panel/MarginContainer/VBoxContainer/ResetButton").pressed.connect(_on_reset_requested)
	pause_menu.get_node("Panel/MarginContainer/VBoxContainer/QuitButton").pressed.connect(_on_quit_requested)
	settings_menu.get_node("Panel/MarginContainer/VBoxContainer/ButtonContainer/BackButton").pressed.connect(UIManager.pop)
	save_load_menu.slot_selected.connect(_on_slot_selected)
	save_load_menu.back_pressed.connect(UIManager.pop)

func _on_reset_requested() -> void:
	UIManager.pop_screen(UIManager.ScreenId.PAUSE)
	var restore_manager = get_node_or_null("/root/GameStateRestoreManager")
	if restore_manager:
		await restore_manager.reset_current_world()

func _on_quit_requested() -> void:
	SaveManager.save_completed.connect(func(_success, _error): get_tree().quit(), CONNECT_ONE_SHOT)
	SaveManager.save_game(get_tree().root.get_meta("current_save_slot", "default"))

func _on_slot_selected(slot_id: String) -> void:
	if save_load_menu.is_save_mode:
		SaveManager.save_game(slot_id)
		UIManager.pop()
		return
	UIManager.pop_screen(UIManager.ScreenId.SAVE_LOAD)
	UIManager.pop_screen(UIManager.ScreenId.PAUSE)
	var restore_manager = get_node_or_null("/root/GameStateRestoreManager")
	if restore_manager:
		await restore_manager.transition_to_world(slot_id)

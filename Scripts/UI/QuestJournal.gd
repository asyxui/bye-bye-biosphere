extends Control

@onready var _quest_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/Content/QuestListPanel/MarginContainer/QuestList
@onready var _quest_title: Label = $Panel/MarginContainer/VBoxContainer/Content/Detail/QuestTitle
@onready var _step_title: Label = $Panel/MarginContainer/VBoxContainer/Content/Detail/StepTitle
@onready var _description: Label = $Panel/MarginContainer/VBoxContainer/Content/Detail/Description
@onready var _objectives: VBoxContainer = $Panel/MarginContainer/VBoxContainer/Content/Detail/Objectives

var _selected_quest_id := ""

func _ready() -> void:
	QuestManager.quest_changed.connect(_refresh)
	GameStateManager.mode_changed.connect(_on_mode_changed)
	$Shade.gui_input.connect(_on_shade_gui_input)
	_refresh()

func _refresh() -> void:
	for child in _quest_list.get_children():
		_quest_list.remove_child(child)
		child.queue_free()
	var quests: Array[Dictionary] = QuestManager.get_journal_entries()
	if quests.is_empty():
		_selected_quest_id = ""
		_update_detail({})
		return
	if not _quest_exists(quests, _selected_quest_id):
		var active_step: Dictionary = QuestManager.get_active_step()
		_selected_quest_id = str(active_step.get("quest_id", quests[0].get("quest_id", "")))
	for quest in quests:
		var quest_id := str(quest.get("quest_id", ""))
		var button := Button.new()
		button.theme_type_variation = &"CompactButton"
		button.custom_minimum_size.y = 42
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = str(quest.get("title", ""))
		button.toggle_mode = true
		button.button_pressed = quest_id == _selected_quest_id
		button.pressed.connect(_select_quest.bind(quest_id))
		_quest_list.add_child(button)
		if quest_id == _selected_quest_id:
			_update_detail(quest)

func _select_quest(quest_id: String) -> void:
	_selected_quest_id = quest_id
	_refresh()

func _update_detail(quest: Dictionary) -> void:
	for child in _objectives.get_children():
		_objectives.remove_child(child)
		child.queue_free()
	if quest.is_empty():
		_quest_title.text = "Field notes"
		_step_title.text = "No active quests"
		_description.text = "New assignments will appear here."
		return
	_quest_title.text = str(quest.get("title", ""))
	var current_step := _get_current_step(quest)
	if current_step.is_empty():
		_step_title.text = "All objectives complete"
		_description.text = "This assignment is complete."
		return
	_step_title.text = str(current_step.get("title", ""))
	_description.text = str(current_step.get("description", ""))
	for objective in current_step.get("objectives", []):
		var objective_row := VBoxContainer.new()
		objective_row.add_theme_constant_override("separation", 3)
		var objective_heading := HBoxContainer.new()
		var objective_label := Label.new()
		objective_label.text = str(objective.get("label", ""))
		objective_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var objective_count := Label.new()
		objective_count.theme_type_variation = &"Data"
		objective_count.text = "%d / %d" % [int(objective.get("current", 0)), int(objective.get("target", 0))]
		objective_heading.add_child(objective_label)
		objective_heading.add_child(objective_count)
		objective_row.add_child(objective_heading)
		var objective_bar := ProgressBar.new()
		objective_bar.custom_minimum_size.y = 5
		objective_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		objective_bar.max_value = maxi(1, int(objective.get("target", 0)))
		objective_bar.value = int(objective.get("current", 0))
		objective_bar.show_percentage = false
		objective_row.add_child(objective_bar)
		_objectives.add_child(objective_row)

func _get_current_step(quest: Dictionary) -> Dictionary:
	var steps: Array = quest.get("steps", [])
	for optional_pass in [false, true]:
		for step in steps:
			if bool(step.get("optional", false)) != optional_pass:
				continue
			if not bool(step.get("complete", false)):
				return step
	return {}

func _quest_exists(quests: Array[Dictionary], quest_id: String) -> bool:
	for quest in quests:
		if str(quest.get("quest_id", "")) == quest_id:
			return true
	return false

func _on_shade_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		UIManager.pop_screen(UIManager.ScreenId.JOURNAL)
		accept_event()

func _on_mode_changed(creative_enabled: bool) -> void:
	if creative_enabled and UIManager.is_open(UIManager.ScreenId.JOURNAL):
		UIManager.pop_screen(UIManager.ScreenId.JOURNAL)

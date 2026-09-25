extends Node

signal quest_changed

const QUESTS_PATH := "res://Resources/Quests"

var _definitions: Array[QuestDefinition] = []
var _progress: Dictionary = {}

func _ready() -> void:
	_load_definitions()
	for definition in _definitions:
		_ensure_quest_progress(str(definition.quest_id))
	GameplayEventBus.event_published.connect(_on_event_published)
	GameStateManager.mode_changed.connect(_on_mode_changed)
	add_to_group("saveable")

func is_active() -> bool:
	return not GameStateManager.is_creative_mode()

func get_active_step() -> Dictionary:
	if not is_active():
		return {}
	for optional_pass in [false, true]:
		for definition in _definitions:
			var quest_state: Dictionary = _ensure_quest_progress(str(definition.quest_id))
			for step in definition.steps:
				if step.optional != optional_pass or _is_step_complete(quest_state, step):
					continue
				return _make_step_view(definition, step, quest_state)
	return {}

func get_journal_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for definition in _definitions:
		var quest_state: Dictionary = _ensure_quest_progress(str(definition.quest_id))
		var step_views: Array[Dictionary] = []
		for step in definition.steps:
			step_views.append(_make_step_view(definition, step, quest_state))
		entries.append({
			"quest_id": str(definition.quest_id),
			"title": definition.title,
			"complete": _is_quest_complete(definition, quest_state),
			"steps": step_views,
		})
	return entries

func get_save_key() -> String:
	return "quests"

func get_save_data() -> Dictionary:
	return {"quests": _progress.duplicate(true)}

func load_save_data(data: Dictionary) -> void:
	_progress = {}
	var saved_progress: Variant = data.get("quests", {})
	if saved_progress is Dictionary:
		_progress = saved_progress.duplicate(true)
	for definition in _definitions:
		var quest_state: Dictionary = _ensure_quest_progress(str(definition.quest_id))
		_refresh_completed_steps(definition, quest_state)
	quest_changed.emit()

func clear_save_data() -> void:
	_progress.clear()
	for definition in _definitions:
		_ensure_quest_progress(str(definition.quest_id))
	quest_changed.emit()

func _load_definitions() -> void:
	_definitions.clear()
	for filename in ResourceLoader.list_directory(QUESTS_PATH):
		if not filename.ends_with(".tres"):
			continue
		var resource: Resource = load(QUESTS_PATH.path_join(filename))
		if resource is QuestDefinition:
			_definitions.append(resource as QuestDefinition)
	_definitions.sort_custom(func(a: QuestDefinition, b: QuestDefinition) -> bool:
		return a.sort_order < b.sort_order or (a.sort_order == b.sort_order and str(a.quest_id) < str(b.quest_id))
	)

func _on_event_published(event_type: StringName, subject_id: String, quantity: int) -> void:
	if not is_active() or quantity <= 0:
		return
	var changed := false
	for definition in _definitions:
		var quest_state: Dictionary = _ensure_quest_progress(str(definition.quest_id))
		var objective_progress: Dictionary = quest_state.get("objectives", {})
		for step in definition.steps:
			for objective in step.objectives:
				if objective.event_type != event_type or (not objective.subject_id.is_empty() and objective.subject_id != subject_id):
					continue
				var objective_key := str(objective.objective_id)
				var previous := int(objective_progress.get(objective_key, 0))
				var next := mini(maxi(0, objective.target_count), previous + quantity)
				if next == previous:
					continue
				objective_progress[objective_key] = next
				changed = true
		quest_state["objectives"] = objective_progress
		_refresh_completed_steps(definition, quest_state)
	if changed:
		quest_changed.emit()

func _on_mode_changed(_creative_enabled: bool) -> void:
	quest_changed.emit()

func _make_step_view(definition: QuestDefinition, step: QuestStepDefinition, quest_state: Dictionary) -> Dictionary:
	var objective_progress: Dictionary = quest_state.get("objectives", {})
	var objective_views: Array[Dictionary] = []
	var step_complete := _is_step_complete(quest_state, step)
	for objective in step.objectives:
		var current := int(objective_progress.get(str(objective.objective_id), 0))
		objective_views.append({
			"label": objective.display_label,
			"current": mini(current, maxi(0, objective.target_count)),
			"target": maxi(0, objective.target_count),
		})
	return {
		"quest_id": str(definition.quest_id),
		"quest_title": definition.title,
		"step_id": str(step.step_id),
		"title": step.title,
		"description": step.description,
		"optional": step.optional,
		"complete": step_complete,
		"objectives": objective_views,
		"progress": _format_progress(objective_views),
	}

func _format_progress(objectives: Array[Dictionary]) -> String:
	var lines: PackedStringArray = []
	for objective in objectives:
		lines.append("%s %d / %d" % [str(objective.label), int(objective.current), int(objective.target)])
	return "   ".join(lines)

func _is_step_complete(quest_state: Dictionary, step: QuestStepDefinition) -> bool:
	var completed_steps: Array = quest_state.get("completed_steps", [])
	if completed_steps.has(str(step.step_id)):
		return true
	if step.objectives.is_empty():
		return false
	var objective_progress: Dictionary = quest_state.get("objectives", {})
	for objective in step.objectives:
		if int(objective_progress.get(str(objective.objective_id), 0)) < maxi(0, objective.target_count):
			return false
	return true

func _is_quest_complete(definition: QuestDefinition, quest_state: Dictionary) -> bool:
	for step in definition.steps:
		if step.optional:
			continue
		if not _is_step_complete(quest_state, step):
			return false
	return true

func _refresh_completed_steps(definition: QuestDefinition, quest_state: Dictionary) -> void:
	var completed_steps: Array = quest_state.get("completed_steps", [])
	for step in definition.steps:
		if _is_step_complete(quest_state, step) and not completed_steps.has(str(step.step_id)):
			completed_steps.append(str(step.step_id))
	quest_state["completed_steps"] = completed_steps
	_progress[str(definition.quest_id)] = quest_state

func _ensure_quest_progress(quest_id: String) -> Dictionary:
	var quest_state: Variant = _progress.get(quest_id, null)
	if not quest_state is Dictionary:
		quest_state = {"objectives": {}, "completed_steps": []}
		_progress[quest_id] = quest_state
	if not quest_state.has("objectives") or not quest_state.objectives is Dictionary:
		quest_state["objectives"] = {}
	if not quest_state.has("completed_steps") or not quest_state.completed_steps is Array:
		quest_state["completed_steps"] = []
	return quest_state
